import SwiftUI

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
                                pasteItem(item)
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
                pasteItem(item)
            }
        }
        // 键盘快捷键
        .background(KeyEventHandler(
            onUp: {
                if let current = selectedIndex, current > 0 {
                    selectedIndex = current - 1
                }
            },
            onDown: {
                if let current = selectedIndex, current < filteredItems.count - 1 {
                    selectedIndex = current + 1
                }
            },
            onEnter: {
                if let index = selectedIndex, index < filteredItems.count {
                    pasteItem(filteredItems[index])
                }
            },
            onEscape: {
                onClose?()
            }
        ))
    }
    
    private func pasteItem(_ item: PasteboardItem) {
        pasteboardManager.pasteItem(item)
        onClose?()
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
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: KeyEventView, context: Context) {}
}

class KeyEventView: NSView {
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            onUp?()
        case 125: // Down arrow
            onDown?()
        case 36: // Enter
            onEnter?()
        case 53: // Escape
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

