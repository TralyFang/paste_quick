import Foundation
import Carbon
import AppKit

/// 全局快捷键管理器
class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "PSTQ"), id: 1)
    private let storageKeyCode = "hotkey_keycode"
    private let storageModifiers = "hotkey_modifiers"
    
    private var keyCode: UInt32
    private var modifiers: UInt32
    var onHotKeyPressed: (() -> Void)?
    
    private init() {
        let storedKey = UserDefaults.standard.integer(forKey: storageKeyCode)
        let storedMods = UserDefaults.standard.integer(forKey: storageModifiers)
        self.keyCode = storedKey == 0 ? UInt32(0x09) : UInt32(storedKey) // default V key
        self.modifiers = storedMods == 0 ? UInt32(cmdKey | shiftKey) : UInt32(storedMods)
    }
    
    /// 注册全局快捷键 (Cmd + Shift + V)
    func register() {
        unregister()
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // 安装事件处理器 (Carbon API)
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                
                var hotKeyID = EventHotKeyID()
                let error = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if error == noErr {
                    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        manager.onHotKeyPressed?()
                    }
                }
                
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        
        if status != noErr {
            NSLog("注册热键事件处理器失败: \(status)")
        }
        
        // 注册快捷键
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        self.hotKeyRef = hotKeyRef
    }
    
    /// 更新快捷键并重新注册
    func updateHotKey(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        UserDefaults.standard.set(Int(keyCode), forKey: storageKeyCode)
        UserDefaults.standard.set(Int(modifiers), forKey: storageModifiers)
        register()
    }
    
    func currentHotKeyDescription() -> String {
        let parts = modifierDescription(from: modifiers)
        let keyName = keyNameFromKeyCode(keyCode)
        return (parts + [keyName]).joined(separator: " + ")
    }
    
    var currentKeyCode: UInt32 { keyCode }
    var currentModifiers: UInt32 { modifiers }
    
    /// 取消注册
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}

// 辅助函数：将字符串转换为 FourCharCode
func FourCharCode(fromString string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for (index, char) in string.utf8.prefix(4).enumerated() {
        result |= FourCharCode(char) << (8 * (3 - index))
    }
    return result
}

// MARK: - HotKey Helpers
extension HotKeyManager {
    func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
    
    func modifierDescription(from mods: UInt32) -> [String] {
        var parts: [String] = []
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        return parts
    }
    
    func keyNameFromKeyCode(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0x31: return "Space"
        case 0x24: return "Enter"
        case 0x33: return "Delete"
        case 0x30: return "Tab"
        case 0x09: return "V"
        case 0x08: return "C"
        case 0x0B: return "B"
        case 0x00: return "A"
        case 0x0E: return "R"
        default:
            if let name = UCKeyTranslateToString(keyCode: keyCode) {
                return name.uppercased()
            }
            return "KeyCode \(keyCode)"
        }
    }
}

// 将 keyCode 转成字符（尽量简单，避免复杂键盘布局差异）
private func UCKeyTranslateToString(keyCode: UInt32) -> String? {
    // 尝试使用上层 API 获取字符
    let source = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
    if let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        return data.withUnsafeBytes { rawPtr -> String? in
            guard let basePtr = rawPtr.baseAddress?
                .assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var keysDown: UInt32 = 0
            var chars: [UniChar] = Array(repeating: 0, count: 4)
            var realLength: Int = 0
            let error = UCKeyTranslate(
                basePtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &keysDown,
                chars.count,
                &realLength,
                &chars
            )
            if error == noErr {
                return String(utf16CodeUnits: chars, count: realLength)
            }
            return nil
        }
    }
    return nil
}

