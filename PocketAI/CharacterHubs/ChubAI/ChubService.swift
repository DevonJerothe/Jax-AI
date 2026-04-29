import Foundation 
import SwiftLLMSDK

public enum ChubSort: String, CaseIterable, Identifiable {
    public var id: Self { self }

    case defaultSort = "default"
    case trending = "n_favorites"
    case popular = "star_count"
    case new = "created_at"
    case updated = "last_activity_at"

    var title: String {
        switch self {
            case .defaultSort: return "Default"
            case .trending: return "Trending"
            case .popular: return "Popular"
            case .new: return "New"
            case .updated: return "Updated"
        }
    }
}

final public class ChubService {
    public var chubSettings: ChubAISettings?

    private var client: CharService
    private var importer: ChubImporter = ChubImporter(urlSession: URLSession.shared)

    public init() {
        self.chubSettings = UserDefaultsManager.shared.fetchChubAISettings()

        self.client = CharService(
            baseUrl: "https://gateway.chub.ai/",
            decoder: JSONDecoder()
        )
    }

    public func updateChubSettings(_ settings: ChubAISettings) {
        chubSettings = settings
        UserDefaultsManager.shared.saveSettings(settings, forKey: .ChubAISettings)
    }

    public func getTags() async -> Result<ChubAITags, APIError> {
        let requestBody = ChubAITagsRequest(
            nsfl: chubSettings?.showNSFL ?? false,
            nsfw: chubSettings?.showNSFW ?? false
        )

        let result = await client.sendRequest(
            forType: ChubAITags.self,
            path: "tags",
            method: "POST", 
            requestBody: try? JSONEncoder().encode(requestBody)
        )

        switch result {
            case .success(let response):
                return .success(response)
            case .failure(let error):
                return .failure(error)
        }
    }

    public func searchCharacters(
        query: String, 
        sort: ChubSort = .defaultSort,
        page: Int = 1, 
        count: Int = 20, 
        topics: [String] = []
    ) async -> Result<ChubCardList, APIError> {
        let requestParams = [
            "first": "\(count)",
            "page": "\(page)",
            "search": query,
            "nsfw": "\(chubSettings?.showNSFW ?? false)",
            "nsfl": "\(chubSettings?.showNSFL ?? false)",
            "topics": topics.joined(separator: ","),
            "excludetopics": chubSettings?.excludedTopics.map { $0.name }.joined(separator: ",") ?? "",
            "sort": sort.rawValue,
            "include_forks": "true"
        ]

        let result = await client.sendRequest(
            forType: ChubSearchResponse.self, 
            path: "search", 
            requestParams: requestParams
        )

        switch result {
            case .success(let response):
                guard let data = response.data else {
                    return .failure(.invalidResponse)
                }
                return .success(data)
            case .failure(let error):
                return .failure(error)
        }
    }

    public func getCharacter(
        character: ChubCardNode
    ) async -> Result<CharacterCard, APIError> {
        guard let fullPath = character.fullPath else {
            return .failure(.invalidURL)
        }

        do {
            let result = try await importer.getCardViaPath(fullPath)
            switch result {
                case .success(let character):
                    return .success(character)
                case .failure(let error):
                    return .failure(error)
            }
        } catch (let error) {
            print("Error: \(error.localizedDescription)")
            return .failure(.invalidResponse)
        }
    }

}