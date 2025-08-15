import Foundation 

public class CharHubModel: Codable {
    public var author: String? 
    public var creatorNotes: String? 
    public var description: String? 
    public var id: String? 
    public var name: String? 
    public var source: String? 
    public var tagline: String? 
    public var type: String?
    public var metadata: CharHubMetaData?
    public var chub: ChubItem?
    public var tags: [String]?

    // manually added fields 
    public var path: String? {
        var fullPath: String = ""
        if source == "chub" {
            fullPath += "\(chub?.fullPath?.first ?? "")/\(chub?.fullPath?.last ?? "")"
        } else if source == "char-tavern" {
            fullPath += "\(id ?? "")/\(name ?? "")"
        } else {
            fullPath += "\(id ?? "")"
        }
        return fullPath
    }

    public var thumbnail: URL? {
        guard let source = source else { return nil }

        let fullPath: String = "\(source)/image/character/\(path ?? "")"

        return URL(string: "https://char-archive.evulid.cc/api/archive/v1/\(fullPath)?max=200&thumbnail=true&format=jpeg&optimize=true")
    }
}

public class CharHubMetaData: Codable {
    public var totalTokens: Int? 
}

public class ChubItem: Codable {
    public var fullPath: [String]?
}

public class CharHubSearchResult: Decodable {
    public var result: [CharHubModel]?
    public var totalPages: Int?

    public init(result: [CharHubModel]?, totalPages: Int?) {
        self.result = result
        self.totalPages = totalPages
    }
}