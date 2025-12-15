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
        // 检查图片
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            if let imageData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: imageData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                
                let preview = "🖼️ 图片 (\(Int(image.size.width))x\(Int(image.size.height)))"
                let item = PasteboardItem(
                    type: .image,
                    content: pngData,
                    preview: preview,
                    imageData: pngData
                )
                addItem(item)
                return
            }
        }
        
        // 检查富文本
        if let rtfData = pasteboard.data(forType: .rtf) {
            if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                let preview = String(attributedString.string.prefix(100))
                let item = PasteboardItem(
                    type: .richText,
                    content: rtfData,
                    preview: preview.isEmpty ? "📄 富文本" : preview
                )
                addItem(item)
                return
            }
        }
        
        // 检查 HTML
        if let htmlData = pasteboard.data(forType: .html) {
            if let htmlString = String(data: htmlData, encoding: .utf8) {
                let preview = htmlString
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .prefix(100)
                let item = PasteboardItem(
                    type: .richText,
                    content: htmlData,
                    preview: String(preview).isEmpty ? "📄 HTML 内容" : String(preview)
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
                let item = PasteboardItem(
                    type: .text,
                    content: textData,
                    preview: preview
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
    func pasteItem(_ item: PasteboardItem) {
        pasteboard.clearContents()
        
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
            // 尝试作为 RTF
            if pasteboard.setData(item.content, forType: .rtf) {
                return
            }
            // 尝试作为 HTML
            if pasteboard.setData(item.content, forType: .html) {
                return
            }
            // 回退到纯文本
            if let string = String(data: item.content, encoding: .utf8) {
                pasteboard.setString(string, forType: .string)
            }
        case .unknown:
            break
        }
        
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

