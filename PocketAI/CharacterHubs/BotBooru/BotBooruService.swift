import Foundation 
import SwiftLLMSDK

public enum BotBooruSort: String, CaseIterable, Identifiable {

    public var id: Self { self }

    case latest = "latest"
    case downloaded = "downloads"
    case mostViewed = "views"

    var title: String {
        switch self {
            case .latest: "Latest"
            case .downloaded: "Most Downloaded"
            case .mostViewed: "Most Viewed"
        }
    }

    var icon: String {
        switch self {
            case .latest: "clock.fill"
            case .downloaded: "square.and.arrow.down.fill"
            case .mostViewed: "eye.fill"
        }
    }
}

public enum BotBooruSortTime: String, CaseIterable, Identifiable {

    public var id: Self { self }

    case week = "week"
    case month = "month"
    case allTime = "all"

    var title: String {
        switch self {
            case .week: "Week"
            case .month: "Month"
            case .allTime: "All Time"
        }
    }
}

final public class BotBooruService {
    public var authSettings: BotBooruAuthSettings?

    private var client: CharService

    public init() {
        self.authSettings = UserDefaultsManager.shared.fetchBotBooruAuthSettings()

        self.client = CharService(
            baseUrl: "https://botbooru.com/", 
            decoder: BotBooruService.makeDecoder()
        )

        self.client.defaultHeaders = { [weak self] in 
            guard let token = self?.authSettings?.token else { return [:] }
            return [
                "Authorization": "Bearer \(token)"
            ]
        }
    }

    public func updateAuthSettings(_ settings: BotBooruAuthSettings) {
        authSettings = settings
        UserDefaultsManager.shared.saveSettings(settings, forKey: .BotBooruAuthSettings)
    }

    public func login(username: String, password: String) async -> Result<Bool, APIError> {
        let result = await client.sendRequest(
            forType: BotBooruLoginResponse.self, 
            path: "auth/token", 
            method: "POST",
            formData: [
                "username": username,
                "password": password
            ], 
            contentType: ContentType.formData
        ) 

        switch result {
            case .success(let response): 
                updateAuthSettings(BotBooruAuthSettings(username: username, password: password, token: response.accessToken))
            case .failure(let error):
                print("BotBooruService error: \(error)")
                return .failure(error)
        }

        return .success(true)
    }

    public func getPosts(
        query: String = "",
        limit: Int = 24, 
        offset: Int = 0, 
        sort: BotBooruSort = .latest,
        sortTime: BotBooruSortTime = .allTime
    ) async -> Result<BotBooruPostModel, APIError> {
        var requestParams = [
            "sort": sort.rawValue, 
            "time_window": sortTime.rawValue,
            "sfw_only": "\(!(authSettings?.showNSFW ?? true))", // invert the value 
            "hide_ai": "\(authSettings?.hideAI ?? true)",
            "limit": "\(limit)",
            "offset": "\(offset)",
        ]
        
        if query.isEmpty == false {
            requestParams["q"] = query
        }
        
        let result = await client.sendRequest(
            forType: BotBooruPostModel.self, 
            path: "posts/",
            requestParams: requestParams
        )

        switch result {
            case .success(let response):
                return .success(response)
            case .failure(let error):
                return .failure(error)
        }
    }

    func getPost(post: BotBooruPostItem) async  -> Result<CharacterCardModel, APIError> {
        let result = await client.sendRequest(
            forType: CharacterCard.self,
            path: "download/json/\(post.id)"
        )

        switch result {
            case .success(let response): 
                // try and get png data
                if let thumbnail = post.thumbnail {
                    let imgData = try? await client.getData(url: thumbnail)
                    response.pngData = imgData
                }

                let charCard = CharacterCardModel.init(fromChub: response)
                return .success(charCard)
            case .failure(let error): 
                print("BotBooruService error: \(error)")
                return .failure(error) 
        }

    }
}

extension BotBooruService {

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder() 
        let dateFormatter = DateFormatter() 

        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }
}
