import SwiftUI

@MainActor
@Observable
final class BotBooruViewModel {
    private let characterStore: CharacterStore 
    private let botBooruService: BotBooruService = .init() 

    var posts: [BotBooruPostItem] = []
    var count: Int = 0 
    var offset: Int = 0 
    var isLoading: Bool = false 
    var loggedIn: Bool
    var loginError: String = ""
    var authSettings: BotBooruAuthSettings
    var searchQuery: String = ""
    var sort: BotBooruSort = .latest
    var sortTime: BotBooruSortTime = .allTime

    init(characterStore: CharacterStore? = nil) {
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        let initialAuthSettings = botBooruService.authSettings ?? BotBooruAuthSettings(username: nil, password: nil, token: nil)
        authSettings = initialAuthSettings

        // check if logged in
        loggedIn = initialAuthSettings.token != nil

        Task {
            if loggedIn {
                // Check if last log in was more than 24 hours ago
                if let lastFetched = initialAuthSettings.lastFetched, Date().timeIntervalSince(lastFetched) > 24 * 60 * 60 {
                    guard let username = initialAuthSettings.username, let password = initialAuthSettings.password else { return }
                    await login(username: username, password: password)
                }
            }
        }
    }

    func loadInitialPosts() async {
        guard loggedIn else { return }
        guard posts.isEmpty else { return }
        guard isLoading == false else { return }

        await getPosts()
    }

    func refreshLogin() async {
        guard let username = authSettings.username, let password = authSettings.password else { return }
        await login(username: username, password: password)
    }

    func login(username: String, password: String) async {
        isLoading = true
        loginError = ""
        let result = await botBooruService.login(username: username, password: password)
        switch result {
            case .success:
                authSettings = botBooruService.authSettings ?? authSettings
                loggedIn = true
                isLoading = false
                await getPosts()
            case .failure:
                logout()
                loginError = "Invalid credentials"
        }
        isLoading = false
    }

    func logout() {
        botBooruService.logout()
        authSettings = BotBooruAuthSettings()
        loggedIn = false
    }

    func updateAuthSettings(_ settings: BotBooruAuthSettings) {
        authSettings = settings
        botBooruService.updateAuthSettings(settings)
        Task { await getPosts(refresh: true) }
    }

    func getPosts(refresh: Bool = false) async {
        guard isLoading == false else { return }
        isLoading = true
        
        if refresh {
            posts = []
            offset = 0
        }
        
        let result = await botBooruService.getPosts(
            query: searchQuery,
            limit: 24,
            offset: offset,
            sort: sort,
            sortTime: sortTime
        )
        switch result {
            case .success(let response):
                posts.append(contentsOf: response.posts)
                count = response.total
                offset = offset + response.posts.count
            case .failure:
                posts = []
                count = 0
        }
        isLoading = false
    }

    func getTags() async {}
    
    func loadMore() async {
        if offset < count {
            await self.getPosts()
        }
    }

    func getCharacter(post: BotBooruPostItem) async -> CharacterCardModel? {
        isLoading = true 
        let result = await botBooruService.getPost(post: post)
        defer { isLoading = false }

        switch result {
            case .success(let response):
                return response
            case .failure:
                print("Error getting character")
                return nil
        }
    }

    func getSortIcon() -> String {
        switch sort {
            case .latest: 
                return "clock.fill" 
            case .downloaded: 
                return "square.and.arrow.down.fill"
            case .mostViewed: 
                return "eye.fill"
        }
    }
}
