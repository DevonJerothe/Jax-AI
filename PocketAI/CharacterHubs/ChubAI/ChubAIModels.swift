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

// NOTE this is not a auth token for the user, rather the token needed to make authenticated requests
public struct ChubTokenResponse: Codable {
    var status: String?
    var csrfToken: String?

    enum CodingKeys: String, CodingKey {
        case status = "status"
        case csrfToken = "csrf_token"
    }
}

public struct ChubloginRequest: Codable {
    var csrfToken: String 
    var emailOrUsername: String 
    var password: String 
    var redirectUrl: String
    var isMobile: Bool 

    init(
        csrfToken: String, 
        emailOrUsername: String, 
        password: String, 
        redirectUrl: String = "https://chub.ai/login",
        isMobile: Bool = false
    ) {
        self.csrfToken = csrfToken
        self.emailOrUsername = emailOrUsername
        self.password = password
        self.redirectUrl = redirectUrl
        self.isMobile = isMobile
    }

    enum CodingKeys: String, CodingKey {
        case csrfToken = "csrf_token"
        case emailOrUsername = "email_or_username"
        case password = "password"
        case redirectUrl = "redirect_url"
        case isMobile = "is_mobile"
    }
}

public struct ChubloginResponse: Codable {
    var gitId: Int
    var username: String 
    var samwise: String?

    enum CodingKeys: String, CodingKey {
        case gitId = "git_id"
        case username = "username"
        case samwise = "samwise"
    }
}

public struct ChubAIUser: Codable {
    var id: Int
    var name: String? 
    var userName: String? 
    var avatarUrl: String? 
    var noNsfw: Bool
    var noNsfl: Bool 

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case userName = "user_name"
        case avatarUrl = "avatar_url"
        case noNsfw = "no_nsfw"
        case noNsfl = "no_nsfl"
    }
}

public struct ChubAISettings: Codable {
    var excludedTopics: [ChubAITag] = []
    var showNSFW: Bool = false
    var showNSFL: Bool = false

    // auth
    var userName: String? 
    var password: String?
    var apiKey: String?
}