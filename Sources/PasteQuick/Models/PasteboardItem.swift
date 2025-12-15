import Foundation
import AppKit

/// 粘贴板条目类型
enum PasteboardItemType {
    case text
    case richText
    case image
    case unknown
}

/// 粘贴板历史条目
struct PasteboardItem: Identifiable, Codable {
    let id: UUID
    let type: PasteboardItemType
    let content: Data
    let preview: String
    let timestamp: Date
    let imageData: Data? // 用于图片类型的预览
    
    init(id: UUID = UUID(), type: PasteboardItemType, content: Data, preview: String, timestamp: Date = Date(), imageData: Data? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.preview = preview
        self.timestamp = timestamp
        self.imageData = imageData
    }
    
    // Codable 支持
    enum CodingKeys: String, CodingKey {
        case id, content, preview, timestamp, imageData, typeRaw
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let typeRaw = try container.decode(Int.self, forKey: .typeRaw)
        type = PasteboardItemType(rawValue: typeRaw) ?? .unknown
        content = try container.decode(Data.self, forKey: .content)
        preview = try container.decode(String.self, forKey: .preview)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type.rawValue, forKey: .typeRaw)
        try container.encode(content, forKey: .content)
        try container.encode(preview, forKey: .preview)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(imageData, forKey: .imageData)
    }
}

extension PasteboardItemType: Codable {
    var rawValue: Int {
        switch self {
        case .text: return 0
        case .richText: return 1
        case .image: return 2
        case .unknown: return 3
        }
    }
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .text
        case 1: self = .richText
        case 2: self = .image
        case 3: self = .unknown
        default: return nil
        }
    }
}

