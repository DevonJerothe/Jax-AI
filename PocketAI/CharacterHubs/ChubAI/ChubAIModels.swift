import Foundation 

public struct ChubAITags: Codable {
    var count: Int
    var tags: [ChubAITag]
    var page: Int
}

public struct ChubAITag: Codable, Identifiable {
    public var id: Int 
    var name: String 
    var nonPrivateProjectsCount: Int 
    var followersCount: Int 
    var title: String 

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case nonPrivateProjectsCount = "non_private_projects_count"
        case followersCount = "followers_count"
        case title = "title"
    }
}

public struct ChubAITagsRequest: Codable {
    var nsfl: Bool 
    var nsfw: Bool 
    var orderBy: String 
    var search: String 
    var sort: String

    public init(
        nsfl: Bool = false, 
        nsfw: Bool = false, 
    ) {
        self.nsfl = nsfl
        self.nsfw = nsfw
        self.orderBy = "followers_count"
        self.search = ""
        self.sort = "followers_count"
    }

    enum CodingKeys: String, CodingKey {
        case nsfl = "nsfl"
        case nsfw = "nsfw"
        case orderBy = "order_by"
        case search = "search"
        case sort = "sort"
    }
}

public struct ChubAISettings: Codable {
    var excludedTopics: [ChubAITag] = []
    var showNSFW: Bool = false
    var showNSFL: Bool = false
}