import Foundation
import AppKit
import CoreImage

/// 二维码扫描器
class QRCodeScanner {
    
    /// 从图片数据中扫描二维码
    /// - Parameter imageData: 图片数据（PNG、JPEG、TIFF等格式）
    /// - Returns: 识别到的二维码字符串，如果没有识别到则返回nil
    static func scanQRCode(from imageData: Data) -> String? {
        guard let ciImage = CIImage(data: imageData) else {
            return nil
        }
        
        // 创建二维码探测器
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                 context: nil,
                                 options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        // 检测二维码特征
        let features = detector?.features(in: ciImage) ?? []
        
        // 提取第一个二维码的内容
        for feature in features {
            if let qrFeature = feature as? CIQRCodeFeature {
                return qrFeature.messageString
            }
        }
        
        return nil
    }
    
    /// 从NSImage中扫描二维码
    /// - Parameter image: NSImage对象
    /// - Returns: 识别到的二维码字符串，如果没有识别到则返回nil
    static func scanQRCode(from image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return scanQRCode(from: pngData)
    }
    
    /// 从文件路径扫描二维码
    /// - Parameter filePath: 图片文件路径
    /// - Returns: 识别到的二维码字符串，如果没有识别到则返回nil
    static func scanQRCode(fromFile filePath: String) -> String? {
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return nil
        }
        
        return scanQRCode(from: imageData)
    }
    
    /// 批量扫描多个二维码
    /// - Parameter imageData: 图片数据
    /// - Returns: 识别到的所有二维码字符串数组
    static func scanMultipleQRCodes(from imageData: Data) -> [String] {
        guard let ciImage = CIImage(data: imageData) else {
            return []
        }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                 context: nil,
                                 options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        let features = detector?.features(in: ciImage) ?? []
        
        var results: [String] = []
        for feature in features {
            if let qrFeature = feature as? CIQRCodeFeature {
                if let message = qrFeature.messageString {
                    results.append(message)
                }
            }
        }
        
        return results
    }
    
    /// 检查图片是否包含二维码
    /// - Parameter imageData: 图片数据
    /// - Returns: 是否包含二维码
    static func containsQRCode(_ imageData: Data) -> Bool {
        guard let ciImage = CIImage(data: imageData) else {
            return false
        }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                 context: nil,
                                 options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        let features = detector?.features(in: ciImage) ?? []
        
        return !features.isEmpty
    }
}