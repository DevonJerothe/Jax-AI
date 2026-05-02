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
                var authSettings = BotBooruAuthSettings(
                    username: username,
                    password: password,
                    token: response.accessToken,
                    lastFetched: Date()
                )
                self.authSettings = authSettings // save so we get auth header access

                // fetch the logged in user for browser settings
                // By default no adult content is shown nore is there a toggle to enable it.
                // Control is based solely on the logged in user view BotBooru's website interface
                // 
                // depending on apple's policies we may need to strip out all browser features
                // if we cant disable this content.
                // 
                // Only way adult content is shown: 
                // - the user is logged into an existing account created via BotBooru
                // - the user has enabled NSFW content in their account settings via BotBooru's website
                let userResult = await getLoggedInUser()
                switch userResult {
                    case .success(let user):
                        authSettings.showNSFW = user.showNsfl
                        updateAuthSettings(authSettings)
                        return .success(true)
                    case .failure(let error):
                        print("BotBooruService error: \(error)")
                        return .failure(error)
                }
                
            case .failure(let error):
                print("BotBooruService error: \(error)")
                return .failure(error)
        }
    }

    public func logout() {
        let authSettings = BotBooruAuthSettings()
        updateAuthSettings(authSettings)
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
            "sfw_only": "\(!(authSettings?.showNSFW ?? true))", // hide by default 
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

    func getLoggedInUser() async -> Result<BotBooruUserModel, APIError> {
        let result = await client.sendRequest(
            forType: BotBooruUserModel.self,
            path: "auth/me"
        )

        switch result {
            case .success(let response):
                return .success(response)
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
