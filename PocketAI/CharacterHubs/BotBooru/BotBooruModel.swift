import Foundation 

public class BotBooruPostModel: Codable {
    var total: Int 
    var posts: [BotBooruPostItem]

    enum CodingKeys: String, CodingKey {
        case total
        case posts
    }
}

public struct BotBooruPostItem: Codable, Identifiable {
    public var id: Int 
    var filename: String 
    var characterName: String 
    var createdAt: Date
    var tags: [BotBooruTagModel]
    var uploaderId: Int 

    var thumbnail: URL? {
        // https://botbooru.com/images/4a89325299cf4ff8a881d65b3b3a1d2f.png?v=1
        // https://botbooru.com/images/preview/480/7c4f972ccc9144e2b17e761bbe186d7b.png?v=1
        return URL(string: "https://botbooru.com/images/preview/480/\(filename)?v=1") ?? nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case filename = "filename"
        case characterName = "character_name"
        case createdAt = "created_at"
        case tags = "tags"
        case uploaderId = "uploader_id"
    }

}
public struct BotBooruTagModel: Codable {
    var id: Int 
    var name: String 
    var category: String 

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
    }
}

// MARK: - Login Response
public struct BotBooruLoginResponse: Codable {
    var accessToken: String 
    var tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

public struct BotBooruAuthSettings: Codable {
    var username: String? 
    var password: String? 
    var token: String? 

    // Settings
    var showNSFW: Bool = false 
    var hideAI: Bool = false
}
