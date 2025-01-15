import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct Song: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    var title: String
    
    init(id: UUID = UUID(), url: URL, title: String) {
        self.id = id
        self.url = url
        self.title = title
    }
    
    // 自定义编码
    enum CodingKeys: String, CodingKey {
        case id, url, title
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encode(title, forKey: .title)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let urlString = try container.decode(String.self, forKey: .url)
        guard let url = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid URL string")
        }
        self.url = url
        title = try container.decode(String.self, forKey: .title)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}
