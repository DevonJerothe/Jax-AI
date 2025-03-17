import Foundation

public class PromptResponse: Codable {
    public var results: [ResultArray]
}

public class ResultArray: Codable {
    public var text: String?
    public var promptTokens: Int?
    public var completionTokens: Int?
}

struct IntResponse: Decodable {
    let value: Int
}

struct StringResponse: Decodable {
    let result: String
}

// TODO: Fix the force unwrapping here. We should handle any errors gracefully
extension PromptResponse {
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestData = try! encoder.encode(self)
        return String(data: requestData, encoding: .utf8)!
    }
}

