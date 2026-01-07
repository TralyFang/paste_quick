import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem?
    var pasteboardManager = PasteboardManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 注册全局快捷键
        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.showMainWindow()
        }
        HotKeyManager.shared.register()
        
        // 创建状态栏图标
        setupStatusBar()
        
        // 设置为不显示在 Dock 中
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "PasteQuick")
        }
        
        let menu = NSMenu()
        menu.addItem(withTitle: "打开粘贴板", action: #selector(openHistory), keyEquivalent: "")
        menu.addItem(withTitle: "识别二维码", action: #selector(scanQRCode), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }
    
    @objc func openHistory() { showMainWindow() }
    @objc func openSettings() { showSettingsWindow() }
    @objc func quitApp() { NSApp.terminate(nil) }
    
    @objc func scanQRCode() {
        // 从粘贴板获取图片并识别二维码
        let pasteboard = NSPasteboard.general
        
        // 检查粘贴板中是否有图片
        let hasImage = pasteboard.data(forType: .png) != nil || 
                      pasteboard.data(forType: .tiff) != nil
        
        guard hasImage else {
            showAlert(title: "未找到图片", message: "请确保粘贴板中包含图片（PNG、TIFF格式）")
            return
        }
        
        // 尝试获取图片数据
        guard let imageData = pasteboard.data(forType: .png) ?? 
                             pasteboard.data(forType: .tiff) else {
            showAlert(title: "图片数据无效", message: "无法读取粘贴板中的图片数据")
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
    
    func showMainWindow() {
        // 如果窗口已存在且可见，则隐藏它；否则显示/创建它
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.orderOut(nil)
            return
        }
        
        // 如果窗口存在但不可见，显示它
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建新窗口
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "PasteQuick - 粘贴板历史"
        window?.titlebarAppearsTransparent = true
        window?.backgroundColor = NSColor.windowBackgroundColor
        window?.level = .floating
        window?.isMovableByWindowBackground = true
        window?.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.isReleasedWhenClosed = false
        window?.delegate = self
        
        // 居中显示
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window!.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY - windowRect.height / 2
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        let contentView = MainWindow(onClose: { [weak self] in
            self?.window?.close()
        })
        .frame(minWidth: 600, minHeight: 500)
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 监听窗口关闭
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    @objc func windowWillClose() {
        // 不退出应用，仅隐藏窗口
        window?.orderOut(nil)
        // 保留引用，便于再次显示
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 捕获关闭按钮行为，改为隐藏
        sender.orderOut(nil)
        return false
    }
    
    func showSettingsWindow() {
        if let settingsWindow = settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.title = "设置"
        settingsWindow?.isReleasedWhenClosed = false
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = settingsWindow!.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY - windowRect.height / 2
            settingsWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        settingsWindow?.contentView = NSHostingView(rootView: SettingsWindow())
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        pasteboardManager.stopMonitoring()
        pasteboardManager.saveHistorySync() // 同步保存历史，防止退出时丢失
    }
}

