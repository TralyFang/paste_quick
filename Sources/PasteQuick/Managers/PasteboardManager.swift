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
        
        // 检查图片 - 优先检查文件URL（当用户复制图片文件时）
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = fileURLs.first,
           firstURL.isFileURL {
            // 检查是否是图片文件
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "ico", "icns"]
            let fileExtension = firstURL.pathExtension.lowercased()
            
            if imageExtensions.contains(fileExtension) {
                // 尝试从文件加载图片
                if let image = NSImage(contentsOf: firstURL) {
                    // 保存文件URL数据（优先）
                    if let fileURLData = pasteboard.data(forType: .fileURL) {
                        representations[NSPasteboard.PasteboardType.fileURL.rawValue] = fileURLData
                    }
                    if let fileNameData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.file-url")) {
                        representations["public.file-url"] = fileNameData
                    }
                    
                    // 尝试读取原始文件数据
                    var originalFileData: Data? = nil
                    if let fileData = try? Data(contentsOf: firstURL) {
                        originalFileData = fileData
                        // 根据文件扩展名设置对应的UTI
                        switch fileExtension {
                        case "png":
                            representations["public.png"] = fileData
                        case "jpg", "jpeg":
                            representations["public.jpeg"] = fileData
                        case "gif":
                            representations["com.compuserve.gif"] = fileData
                        case "tiff", "tif":
                            representations[NSPasteboard.PasteboardType.tiff.rawValue] = fileData
                        case "heic", "heif":
                            representations["public.heic"] = fileData
                        default:
                            break
                        }
                    }
                    
                    // 保存图片数据的所有格式
                    if let tiff = image.tiffRepresentation {
                        representations[NSPasteboard.PasteboardType.tiff.rawValue] = tiff
                    }
                    
                    // 尝试获取粘贴板中的原始格式数据（可能比文件数据更准确）
                    if let pngData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")) {
                        representations["public.png"] = pngData
                    }
                    if let jpegData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                        representations["public.jpeg"] = jpegData
                    }
                    
                    // 转换为PNG用于存储和预览
                    if let imageData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: imageData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        
                        // 优先使用原始文件数据作为content，如果没有则使用PNG
                        let contentData = originalFileData ?? pngData
                        
                        let preview = "🖼️ 图片 (\(Int(image.size.width))x\(Int(image.size.height)))"
                        let item = PasteboardItem(
                            type: .image,
                            content: contentData,
                            preview: preview,
                            imageData: pngData,
                            representations: representations.isEmpty ? nil : representations
                        )
                        addItem(item)
                        return
                    }
                }
            }
        }
        
        // 检查图片数据（直接复制图片内容时）
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            if let imageData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: imageData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                
                // 保存所有可用的图片格式
                if let tiff = image.tiffRepresentation {
                    representations[NSPasteboard.PasteboardType.tiff.rawValue] = tiff
                }
                
                // 尝试获取原始格式数据
                if let pngDataRaw = pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")) {
                    representations["public.png"] = pngDataRaw
                }
                if let jpegData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                    representations["public.jpeg"] = jpegData
                }
                if let heicData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.heic")) {
                    representations["public.heic"] = heicData
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
        
        // 检查原始图片数据（某些应用可能直接提供数据）
        let imageTypes = [
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.tiff"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("com.compuserve.gif")
        ]
        
        for imageType in imageTypes {
            if let imageData = pasteboard.data(forType: imageType),
               let image = NSImage(data: imageData) {
                representations[imageType.rawValue] = imageData
                
                // 转换为PNG用于存储和预览
                if let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    
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
            
            // 检查是否已存在相同内容
            if let existingIndex = self.findDuplicateIndex(for: item) {
                // 如果已存在，将其移动到最前面并更新时间戳
                let existingItem = self.items.remove(at: existingIndex)
                let updatedItem = PasteboardItem(
                    id: existingItem.id, // 保持相同的ID
                    type: existingItem.type,
                    content: existingItem.content,
                    preview: existingItem.preview,
                    timestamp: Date(), // 更新时间戳
                    imageData: existingItem.imageData,
                    representations: existingItem.representations
                )
                self.items.insert(updatedItem, at: 0)
            } else {
                // 插入新条目到开头
                self.items.insert(item, at: 0)
            }
            
            self.trimHistoryAndSave()
        }
    }
    
    /// 查找重复条目的索引
    private func findDuplicateIndex(for item: PasteboardItem) -> Int? {
        for (index, existingItem) in items.enumerated() {
            if isDuplicate(item, existingItem) {
                return index
            }
        }
        return nil
    }
    
    /// 判断两个条目是否重复
    private func isDuplicate(_ item1: PasteboardItem, _ item2: PasteboardItem) -> Bool {
        // 类型不同肯定不是重复
        if item1.type != item2.type {
            return false
        }
        
        switch item1.type {
        case .text:
            // 对于文本，比较内容数据
            return item1.content == item2.content
            
        case .richText:
            // 对于富文本，比较内容数据
            return item1.content == item2.content
            
        case .image:
            // 对于图片，比较内容数据（PNG格式）
            return item1.content == item2.content
            
        case .unknown:
            // 未知类型，比较内容数据
            return item1.content == item2.content
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
        
        // 对于图片类型，确保图片对象也被写入（即使已有representations）
        if item.type == .image {
            // 优先使用原始格式数据
            if let reps = item.representations {
                // 检查是否有原始格式数据（PNG、JPEG等）
                var hasOriginalFormat = false
                for uti in ["public.png", "public.jpeg", "public.tiff", "public.heic"] {
                    if reps[uti] != nil {
                        hasOriginalFormat = true
                        break
                    }
                }
                
                // 如果没有原始格式，或者需要确保NSImage对象可用，则写入图片对象
                if !hasOriginalFormat || !wroteAny {
                    if let image = NSImage(data: item.content) {
                        pasteboard.writeObjects([image])
                        wroteAny = true
                    }
                }
            } else {
                // 没有representations，直接写入图片对象
                if let image = NSImage(data: item.content) {
                    pasteboard.writeObjects([image])
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
            self?.saveHistoryAsync()
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

