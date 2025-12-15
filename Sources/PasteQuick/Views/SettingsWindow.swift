import SwiftUI
import Carbon

struct SettingsWindow: View {
    @ObservedObject var pasteboardManager = PasteboardManager.shared
    @State private var hotKeyDescription: String = HotKeyManager.shared.currentHotKeyDescription()
    @State private var isRecording: Bool = false
    @State private var recordHint: String = "点击“录制快捷键”后，按下新的组合键"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title2.bold())
            
            Divider()
            
            // 历史记录上限
            VStack(alignment: .leading, spacing: 8) {
                Text("历史记录上限")
                    .font(.headline)
                HStack {
                    Slider(value: Binding(
                        get: { Double(pasteboardManager.maxItems) },
                        set: { pasteboardManager.maxItems = Int($0) }
                    ), in: 10...200, step: 5)
                    Text("\(pasteboardManager.maxItems) 条")
                        .frame(width: 80, alignment: .trailing)
                        .font(.subheadline)
                }
                Text("重启后保留历史记录，最多 200 条。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 快捷键设置
            VStack(alignment: .leading, spacing: 8) {
                Text("快捷键")
                    .font(.headline)
                HStack {
                    Text(hotKeyDescription)
                        .font(.body.monospaced())
                    Spacer()
                    Button(isRecording ? "正在录制..." : "录制快捷键") {
                        isRecording.toggle()
                        recordHint = isRecording ? "按下新的组合键，例如 ⌘ ⇧ V" : "点击“录制快捷键”后，按下新的组合键"
                    }
                    .disabled(isRecording == false ? false : false)
                }
                Text(recordHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isRecording {
                    KeyCaptureView { keyCode, flags in
                        let mods = HotKeyManager.shared.carbonModifiers(from: flags)
                        HotKeyManager.shared.updateHotKey(keyCode: keyCode, modifiers: mods)
                        hotKeyDescription = HotKeyManager.shared.currentHotKeyDescription()
                        isRecording = false
                        recordHint = "已更新快捷键"
                    }
                    .frame(height: 1) // 隐藏视图
                }
            }
            
            // 使用说明
            VStack(alignment: .leading, spacing: 8) {
                Text("使用说明")
                    .font(.headline)
                Text("1) 在任意应用按下快捷键唤出历史列表；2) 方向键选择，Enter 粘贴；3) 如需权限，请在“系统设置 > 隐私与安全性 > 辅助功能”授权。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 520, height: 320)
    }
}

/// 捕获快捷键输入
struct KeyCaptureView: NSViewRepresentable {
    var onCapture: (UInt32, NSEvent.ModifierFlags) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyCaptureNSView: NSView {
    var onCapture: ((UInt32, NSEvent.ModifierFlags) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard event.keyCode != 0 else { return }
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if mods.isEmpty { return } // 需要至少一个修饰键
        onCapture?(UInt32(event.keyCode), mods)
    }
}

