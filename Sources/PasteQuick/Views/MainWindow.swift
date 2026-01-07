import SwiftUI
import AppKit

/// 主窗口视图
struct MainWindow: View {
    @ObservedObject var pasteboardManager = PasteboardManager.shared
    @State private var selectedIndex: Int? = nil
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    var onClose: (() -> Void)?
    
    var filteredItems: [PasteboardItem] {
        if searchText.isEmpty {
            return pasteboardManager.items
        }
        return pasteboardManager.items.filter { item in
            item.preview.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索粘贴板历史...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isSearchFocused = true
                        }
                    }
                
                Spacer()
                
                // 上下按钮
                HStack(spacing: 8) {
                    Button {
                        moveUp()
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .help("上一条 (↑)")
                    
                    Button {
                        moveDown()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .help("下一条 (↓)")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 列表
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    Text(searchText.isEmpty ? "暂无粘贴板历史" : "未找到匹配项")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        PasteboardItemRow(item: item, isSelected: selectedIndex == index)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                pasteItem(item, simulatePaste: true)
                            }
                            .contextMenu {
                                if item.type == .image {
                                    Button {
                                        scanQRCodeFromItem(item)
                                    } label: {
                                        Label("识别二维码", systemImage: "qrcode.viewfinder")
                                    }
                                    Divider()
                                }
                                
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label("删除此条", systemImage: "trash")
                                }
                            }
                            .onAppear {
                                if selectedIndex == nil {
                                    selectedIndex = 0
                                }
                            }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { newIndex in
                        if let index = newIndex, index < filteredItems.count {
                            withAnimation {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            // 底部信息栏
            HStack {
                Text("\(filteredItems.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清空") {
                    pasteboardManager.clearAll()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .onAppear {
            selectedIndex = filteredItems.isEmpty ? nil : 0
        }
        .onExitCommand {
            onClose?()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PasteItem"))) { notification in
            if let index = selectedIndex, index < filteredItems.count {
                let item = filteredItems[index]
                pasteItem(item, simulatePaste: true)
            }
        }
        // 键盘快捷键
        .background(KeyEventHandler(
            onUp: {
                moveUp()
            },
            onDown: {
                moveDown()
            },
            onEnter: {
                if let index = selectedIndex, index < filteredItems.count {
                    pasteItem(filteredItems[index], simulatePaste: true)
                }
            },
            onCopy: {
                if let index = selectedIndex, index < filteredItems.count {
                    pasteItem(filteredItems[index], simulatePaste: false)
                }
            },
            onQRCode: {
                if let index = selectedIndex, index < filteredItems.count {
                    let item = filteredItems[index]
                    if item.type == .image {
                        scanQRCodeFromItem(item)
                    }
                }
            },
            onEscape: {
                onClose?()
            }
        ))
    }
    
    private func deleteItem(_ item: PasteboardItem) {
        pasteboardManager.removeItem(item)
        // 更新选中索引，确保不会越界
        DispatchQueue.main.async {
            let count = self.filteredItems.count
            if count == 0 {
                self.selectedIndex = nil
            } else {
                let current = self.selectedIndex ?? 0
                self.selectedIndex = min(current, count - 1)
            }
        }
    }
    
    private func pasteItem(_ item: PasteboardItem, simulatePaste: Bool) {
        pasteboardManager.pasteItem(item, simulatePaste: simulatePaste)
        onClose?()
    }
    
    private func moveUp() {
        if let current = selectedIndex, current > 0 {
            selectedIndex = current - 1
        }
    }
    
    private func moveDown() {
        if let current = selectedIndex, current < filteredItems.count - 1 {
            selectedIndex = current + 1
        } else if selectedIndex == nil, !filteredItems.isEmpty {
            selectedIndex = 0
        }
    }
    
    private func scanQRCodeFromItem(_ item: PasteboardItem) {
        guard item.type == .image else {
            showAlert(title: "错误", message: "只有图片类型才能识别二维码")
            return
        }
        
        guard let imageData = item.imageData else {
            showAlert(title: "错误", message: "图片数据无效")
            return
        }
        
        // 检查图片是否包含二维码
        guard QRCodeScanner.containsQRCode(imageData) else {
            showAlert(title: "未识别到二维码", message: "请确保图片中包含有效的二维码")
            return
        }
        
        // 扫描二维码
        guard let result = QRCodeScanner.scanQRCode(from: imageData) else {
            showAlert(title: "二维码识别失败", message: "无法识别二维码内容")
            return
        }
        
        // 将识别结果复制到粘贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
        
        // 显示成功消息，如果内容太长则截断
        let displayResult = result.count > 200 ? String(result.prefix(200)) + "..." : result
        showAlert(title: "二维码识别成功", message: "已识别二维码内容并复制到粘贴板：\n\n\(displayResult)")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

/// 粘贴板条目行视图
struct PasteboardItemRow: View {
    let item: PasteboardItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: iconForType(item.type))
                .foregroundColor(colorForType(item.type))
                .frame(width: 20)
            
            // 内容预览
            VStack(alignment: .leading, spacing: 4) {
                if item.type == .image, let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 60)
                } else {
                    Text(item.preview)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    Text(timeString(from: item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
    }
    
    private func iconForType(_ type: PasteboardItemType) -> String {
        switch type {
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .unknown: return "questionmark"
        }
    }
    
    private func colorForType(_ type: PasteboardItemType) -> Color {
        switch type {
        case .text: return .blue
        case .richText: return .purple
        case .image: return .orange
        case .unknown: return .gray
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// 键盘事件处理
struct KeyEventHandler: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onCopy: () -> Void
    let onQRCode: () -> Void
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onCopy = onCopy
        view.onQRCode = onQRCode
        view.onEscape = onEscape
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyEventView, context: Context) {}
}

class KeyEventView: NSView {
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onEnter: (() -> Void)?
    var onCopy: (() -> Void)?
    var onQRCode: (() -> Void)?
    var onEscape: (() -> Void)?
    private var localMonitor: Any?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
        
        // 拦截窗口内的按键事件，即使焦点在 TextField 也能响应方向键
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.handle(event: event) {
                return nil
            }
            return event
        }
    }
    
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if handle(event: event) {
            return
        }
        super.keyDown(with: event)
    }
    
    private func handle(event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "c":
                onCopy?()
                return true
            case "q":
                onQRCode?()
                return true
            default:
                break
            }
        }
        
        switch event.keyCode {
        case 126: // Up arrow
            onUp?()
            return true
        case 125: // Down arrow
            onDown?()
            return true
        case 36: // Enter
            onEnter?()
            return true
        case 53: // Escape
            onEscape?()
            return true
        default:
            return false
        }
    }
}

