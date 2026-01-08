import Foundation
import AppKit

/// 二维码识别服务
class QRCodeService {
    
    /// 从图片数据识别二维码
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - pasteboard: 粘贴板对象（可选，用于复制结果）
    ///   - showAlert: 显示提示框的函数
    /// - Returns: 是否成功识别并处理
    @discardableResult
    static func scanQRCode(from imageData: Data, 
                          pasteboard: NSPasteboard? = nil,
                          showAlert: @escaping (String, String) -> Void) -> Bool {
        // 检查图片是否包含二维码
        guard QRCodeScanner.containsQRCode(imageData) else {
            showAlert("未识别到二维码", "请确保图片中包含有效的二维码")
            return false
        }
        
        // 扫描二维码
        guard let result = QRCodeScanner.scanQRCode(from: imageData) else {
            showAlert("二维码识别失败", "无法识别二维码内容")
            return false
        }
        
        // 使用URLHandler处理二维码识别结果
        URLHandler.handleQRCodeResult(result, pasteboard: pasteboard, showAlert: showAlert)
        return true
    }
    
    /// 从粘贴板识别二维码
    /// - Parameters:
    ///   - pasteboard: 粘贴板对象
    ///   - showAlert: 显示提示框的函数
    /// - Returns: 是否成功识别并处理
    @discardableResult
    static func scanQRCodeFromPasteboard(_ pasteboard: NSPasteboard = NSPasteboard.general,
                                        showAlert: @escaping (String, String) -> Void) -> Bool {
        guard let imageData = getImageDataFromPasteboard(pasteboard) else {
            showAlert("未找到图片", "请确保粘贴板中包含图片（PNG、JPEG、TIFF、HEIC、GIF格式）")
            return false
        }
        
        return scanQRCode(from: imageData, pasteboard: pasteboard, showAlert: showAlert)
    }
    
    /// 从PasteboardItem识别二维码
    /// - Parameters:
    ///   - item: PasteboardItem对象
    ///   - pasteboard: 粘贴板对象（可选，用于复制结果）
    ///   - showAlert: 显示提示框的函数
    /// - Returns: 是否成功识别并处理
    @discardableResult
    static func scanQRCode(from item: PasteboardItem,
                          pasteboard: NSPasteboard? = nil,
                          showAlert: @escaping (String, String) -> Void) -> Bool {
        guard item.type == .image else {
            showAlert("错误", "只有图片类型才能识别二维码")
            return false
        }
        
        guard let imageData = item.imageData else {
            showAlert("错误", "图片数据无效")
            return false
        }
        
        return scanQRCode(from: imageData, pasteboard: pasteboard, showAlert: showAlert)
    }
    
    /// 从图片数据识别二维码（系统服务版本）
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - pasteboard: 粘贴板对象
    ///   - error: 错误指针
    /// - Returns: 是否成功识别
    @discardableResult
    static func scanQRCodeForService(from imageData: Data,
                                    pasteboard: NSPasteboard,
                                    error: AutoreleasingUnsafeMutablePointer<NSString>) -> Bool {
        // 检查图片是否包含二维码
        guard QRCodeScanner.containsQRCode(imageData) else {
            error.pointee = "未识别到二维码" as NSString
            return false
        }
        
        // 扫描二维码
        guard let result = QRCodeScanner.scanQRCode(from: imageData) else {
            error.pointee = "二维码识别失败" as NSString
            return false
        }
        
        // 使用URLHandler处理二维码识别结果
        URLHandler.handleQRCodeResult(result, pasteboard: pasteboard) { title, message in
            // 在服务中显示提示框
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
        
        return true
    }
    
    /// 从粘贴板识别二维码（系统服务版本）
    /// - Parameters:
    ///   - pasteboard: 粘贴板对象
    ///   - error: 错误指针
    /// - Returns: 是否成功识别
    @discardableResult
    static func scanQRCodeFromPasteboardForService(_ pasteboard: NSPasteboard,
                                                  error: AutoreleasingUnsafeMutablePointer<NSString>) -> Bool {
        guard let imageData = getImageDataFromPasteboard(pasteboard) else {
            error.pointee = "未找到图片数据" as NSString
            return false
        }
        
        return scanQRCodeForService(from: imageData, pasteboard: pasteboard, error: error)
    }
    
    /// 从粘贴板获取图片数据（公共方法）
    /// - Parameter pasteboard: 粘贴板对象
    /// - Returns: 图片数据，如果未找到则返回nil
    private static func getImageDataFromPasteboard(_ pasteboard: NSPasteboard) -> Data? {
        // 支持的图片格式类型
        let imageTypes = [
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.tiff"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType.tiff,
            NSPasteboard.PasteboardType("public.image")
        ]
        
        // 尝试获取图片数据 - 优先获取原始格式
        var imageData: Data?
        
        // 1. 尝试获取原始图片数据
        for imageType in imageTypes {
            if let data = pasteboard.data(forType: imageType) {
                imageData = data
                break
            }
        }
        
        // 2. 如果没有原始数据，尝试从NSImage对象获取TIFF数据
        if imageData == nil {
            if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
               let firstImage = images.first,
               let tiffData = firstImage.tiffRepresentation {
                imageData = tiffData
            }
        }
        
        return imageData
    }
}