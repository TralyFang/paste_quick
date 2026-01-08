import Foundation
import AppKit

/// URL处理工具类
class URLHandler {
    
    /// 检查字符串是否是网页地址
    /// - Parameter string: 要检查的字符串
    /// - Returns: 如果是网页地址返回true，否则返回false
    static func isWebURL(_ string: String) -> Bool {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否是有效的URL
        if let url = URL(string: trimmedString) {
            // 检查是否是HTTP/HTTPS协议
            if let scheme = url.scheme?.lowercased() {
                return scheme == "http" || scheme == "https"
            }
        }
        
        // 检查是否是常见的网址格式（没有协议前缀）
        let urlPatterns = [
            #"^www\.[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?(?:\/\S*)?$"#, // www.example.com
            #"^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?(?:\/\S*)?$"#, // example.com
            #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(?::\d+)?(?:\/\S*)?$"#, // IP地址
            #"^localhost(?::\d+)?(?:\/\S*)?$"#, // localhost
            #"^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.local(?:\/\S*)?$"# // .local域名
        ]
        
        for pattern in urlPatterns {
            if trimmedString.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// 打开网页地址
    /// - Parameter urlString: 网页地址字符串
    /// - Returns: 是否成功打开
    @discardableResult
    static func openWebURL(_ urlString: String) -> Bool {
        let trimmedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalURLString = trimmedString
        
        // 如果没有协议前缀，添加https://
        if !trimmedString.lowercased().hasPrefix("http://") && !trimmedString.lowercased().hasPrefix("https://") {
            finalURLString = "https://\(trimmedString)"
        }
        
        guard let url = URL(string: finalURLString) else {
            return false
        }
        
        return NSWorkspace.shared.open(url)
    }
    
    /// 处理二维码识别结果，如果是网页地址则询问用户操作
    /// - Parameters:
    ///   - qrCodeResult: 二维码识别结果
    ///   - pasteboard: 粘贴板对象（可选，用于复制结果）
    ///   - showAlert: 显示提示框的函数
    static func handleQRCodeResult(_ qrCodeResult: String, 
                                  pasteboard: NSPasteboard? = nil,
                                  showAlert: @escaping (String, String) -> Void) {
        // 检查是否是网页地址
        if isWebURL(qrCodeResult) {
            // 询问用户是否要打开网页
            let alert = NSAlert()
            alert.messageText = "识别到网页地址"
            alert.informativeText = "是否要打开以下网页？\n\n\(qrCodeResult)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "打开网页")
            alert.addButton(withTitle: "复制到粘贴板")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn: // 打开网页
                if openWebURL(qrCodeResult) {
                    showAlert("已打开网页", "网页已在浏览器中打开")
                } else {
                    showAlert("错误", "无法打开网页地址")
                }
            case .alertSecondButtonReturn: // 复制到粘贴板
                if let pasteboard = pasteboard {
                    pasteboard.clearContents()
                    pasteboard.setString(qrCodeResult, forType: .string)
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(qrCodeResult, forType: .string)
                }
                showAlert("已复制", "网页地址已复制到粘贴板")
            default: // 取消
                break
            }
        } else {
            // 非网页地址，直接复制到粘贴板
            if let pasteboard = pasteboard {
                pasteboard.clearContents()
                pasteboard.setString(qrCodeResult, forType: .string)
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(qrCodeResult, forType: .string)
            }
            
            // 显示成功消息，如果内容太长则截断
            let displayResult = qrCodeResult.count > 200 ? String(qrCodeResult.prefix(200)) + "..." : qrCodeResult
            showAlert("二维码识别成功", "已识别二维码内容并复制到粘贴板：\n\n\(displayResult)")
        }
    }
    
    /// 复制字符串到粘贴板
    /// - Parameter string: 要复制的字符串
    static func copyToPasteboard(_ string: String, pasteboard: NSPasteboard = NSPasteboard.general) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}