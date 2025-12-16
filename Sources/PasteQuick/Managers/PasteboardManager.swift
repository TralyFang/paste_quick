import Foundation
import AppKit

/// 粘贴板管理器：监听系统粘贴板变化并存储历史记录
class PasteboardManager: ObservableObject {
    static let shared = PasteboardManager()
    
    @Published var items: [PasteboardItem] = []
    @Published var maxItems: Int = 50 {
        didSet {
            let clamped = max(10, min(200, maxItems))
            if clamped != maxItems {
                maxItems = clamped
                return
            }
            saveHistoryLimit(clamped)
            trimHistoryAndSave()
        }
    }
    
    private let settingsKeyHistoryLimit = "historyLimit"
    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PasteQuick/history.json")
    }()
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    
    private init() {
        // 先初始化存储属性，避免在调用方法时使用未初始化的 self
        self.maxItems = 50
        self.items = []
        self.changeCount = pasteboard.changeCount
        
        // 加载持久化的设置与历史
        restoreFromDisk()
        
        startMonitoring()
    }
    
    /// 开始监听粘贴板变化
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    /// 停止监听
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 检查粘贴板是否有变化
    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        if currentChangeCount != changeCount {
            changeCount = currentChangeCount
            captureCurrentPasteboard()
        }
    }
    
    /// 捕获当前粘贴板内容
    private func captureCurrentPasteboard() {
        var representations: [String: Data] = [:]
        
        // 检查图片
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            if let imageData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: imageData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                
                // 保存原始 tiff
                if let tiff = image.tiffRepresentation {
                    representations[NSPasteboard.PasteboardType.tiff.rawValue] = tiff
                }
                
                let preview = "🖼️ 图片 (\(Int(image.size.width))x\(Int(image.size.height)))"
                let item = PasteboardItem(
                    type: .image,
                    content: pngData,
                    preview: preview,
                    imageData: pngData,
                    representations: representations.isEmpty ? nil : representations
                )
                addItem(item)
                return
            }
        }
        
        // 检查富文本
        if let rtfData = pasteboard.data(forType: .rtf) {
            representations[NSPasteboard.PasteboardType.rtf.rawValue] = rtfData
            if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                let preview = String(attributedString.string.prefix(100))
                let item = PasteboardItem(
                    type: .richText,
                    content: rtfData,
                    preview: preview.isEmpty ? "📄 富文本" : preview,
                    representations: representations.isEmpty ? nil : representations
                )
                addItem(item)
                return
            }
        }
        
        // 检查 HTML
        if let htmlData = pasteboard.data(forType: .html) {
            representations[NSPasteboard.PasteboardType.html.rawValue] = htmlData
            if let attributed = NSAttributedString(html: htmlData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                let plain = attributed.string
                let preview = plain.prefix(200)
                let item = PasteboardItem(
                    type: .richText,
                    content: htmlData,
                    preview: String(preview).isEmpty ? "📄 HTML 内容" : String(preview),
                    representations: representations.isEmpty ? nil : representations
                )
                addItem(item)
                return
            }
        }
        
        // 检查纯文本
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 避免重复添加相同的文本
            if let lastItem = items.first, lastItem.type == .text {
                if let lastText = String(data: lastItem.content, encoding: .utf8), lastText == string {
                    return // 忽略重复内容
                }
            }
            
            let preview = String(string.prefix(100))
            if let textData = string.data(using: .utf8) {
                if let plainData = pasteboard.data(forType: .string) {
                    representations[NSPasteboard.PasteboardType.string.rawValue] = plainData
                }
                if let utf8Data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.utf8-plain-text")) {
                    representations["public.utf8-plain-text"] = utf8Data
                }
                let item = PasteboardItem(
                    type: .text,
                    content: textData,
                    preview: preview,
                    representations: representations.isEmpty ? nil : representations
                )
                addItem(item)
            }
        }
    }
    
    /// 添加新条目
    private func addItem(_ item: PasteboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 避免重复（基于预览内容）
            if !self.items.isEmpty && self.items.first?.preview == item.preview {
                return
            }
            
            // 插入到开头
            self.items.insert(item, at: 0)
            
            self.trimHistoryAndSave()
        }
    }
    
    /// 将指定条目粘贴到系统粘贴板
    /// 将指定条目写入系统粘贴板，并可选模拟 Cmd+V
    func pasteItem(_ item: PasteboardItem, simulatePaste: Bool = true) {
        pasteboard.clearContents()
        
        // 优先还原存储的所有格式
        var wroteAny = false
        if let reps = item.representations {
            for (uti, data) in reps {
                let type = NSPasteboard.PasteboardType(uti)
                if pasteboard.setData(data, forType: type) {
                    wroteAny = true
                }
            }
        }
        
        if !wroteAny {
            switch item.type {
            case .image:
                if let image = NSImage(data: item.content) {
                    pasteboard.writeObjects([image])
                }
            case .text:
                if let string = String(data: item.content, encoding: .utf8) {
                    pasteboard.setString(string, forType: .string)
                }
            case .richText:
                let plainText: String? = {
                    if let attr = NSAttributedString(rtf: item.content, documentAttributes: nil) {
                        return attr.string
                    }
                    if let attributed = NSAttributedString(html: item.content, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                        return attributed.string
                    }
                    return String(data: item.content, encoding: .utf8)
                }()
                
                pasteboard.setData(item.content, forType: .rtf)
                pasteboard.setData(item.content, forType: .html)
                if let text = plainText {
                    pasteboard.setString(text, forType: .string)
                }
            case .unknown:
                break
            }
        } else {
            // 如果写入了多格式，仍然补充纯文本，避免部分应用读不到
            if let text = {
                switch item.type {
                case .text:
                    return String(data: item.content, encoding: .utf8)
                case .richText:
                    if let attr = NSAttributedString(rtf: item.content, documentAttributes: nil) {
                        return attr.string
                    }
                    if let attributed = NSAttributedString(html: item.content, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                        return attributed.string
                    }
                    return String(data: item.content, encoding: .utf8)
                case .image, .unknown:
                    return nil
                }
            }() {
                pasteboard.setString(text, forType: .string)
            }
        }
        
        // 将当前条目移动到最新（顶端），避免重复新增
        promote(item)
        
        guard simulatePaste else { return }
        
        // 模拟 Cmd+V 快捷键来粘贴
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .hidSystemState)
            
            // V 键的虚拟键码是 0x09
            let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            keyDownEvent?.flags = [.maskCommand]
            keyUpEvent?.flags = [.maskCommand]
            
            keyDownEvent?.post(tap: .cghidEventTap)
            keyUpEvent?.post(tap: .cghidEventTap)
        }
    }
    
    /// 删除指定条目
    func removeItem(_ item: PasteboardItem) {
        DispatchQueue.main.async { [weak self] in
            self?.items.removeAll { $0.id == item.id }
        }
    }
    
    /// 清空所有历史
    func clearAll() {
        DispatchQueue.main.async { [weak self] in
            self?.items.removeAll()
            self?.saveHistoryAsync()
        }
    }
    
    /// 将指定条目移动到列表顶部
    private func promote(_ item: PasteboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let idx = self.items.firstIndex(where: { $0.id == item.id }) {
                let target = self.items.remove(at: idx)
                self.items.insert(target, at: 0)
                self.trimHistoryAndSave()
            }
        }
    }
    
    // MARK: - 持久化
    private func ensureStorageDirectory() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    private func restoreFromDisk() {
        let limit = loadHistoryLimit()
        self.maxItems = limit
        self.items = loadHistory(limit: limit)
    }
    
    private func loadHistory(limit: Int? = nil) -> [PasteboardItem] {
        ensureStorageDirectory()
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        if let decoded = try? JSONDecoder().decode([PasteboardItem].self, from: data) {
            let maxCount = limit ?? maxItems
            return Array(decoded.prefix(maxCount))
        }
        return []
    }
    
    private func saveHistoryAsync() {
        let snapshot = items
        let url = storageURL
        ensureStorageDirectory()
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
    
    /// 立即同步保存（应用退出前调用）
    func saveHistorySync() {
        let snapshot = items
        ensureStorageDirectory()
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    private func trimHistoryAndSave() {
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        saveHistoryAsync()
    }
    
    private func loadHistoryLimit() -> Int {
        let value = UserDefaults.standard.integer(forKey: settingsKeyHistoryLimit)
        let limit = value == 0 ? 50 : value
        return max(10, min(200, limit))
    }
    
    private func saveHistoryLimit(_ value: Int) {
        UserDefaults.standard.set(value, forKey: settingsKeyHistoryLimit)
    }
}

