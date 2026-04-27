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
    var authSettings: BotBooruAuthSettings
    var searchQuery: String = ""
    var sort: BotBooruSort = .latest
    var sortTime: BotBooruSortTime = .allTime

    init(characterStore: CharacterStore? = nil, loadPosts: Bool = true) {
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        let initialAuthSettings = botBooruService.authSettings ?? BotBooruAuthSettings(username: nil, password: nil, token: nil)
        authSettings = initialAuthSettings

        // check if logged in
        loggedIn = initialAuthSettings.token != nil
        
        if loggedIn && loadPosts {
            Task {
                await getPosts()
            }
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        let result = await botBooruService.login(username: username, password: password)
        switch result {
            case .success:
                authSettings = botBooruService.authSettings ?? authSettings
                loggedIn = true
                await getPosts()
            case .failure:
                loggedIn = false
        }
        isLoading = false
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
    
    func loadMore() async {
        if offset < count {
            await self.getPosts()
        }
    }

    // TODO: We should create a new page to view the card details before saving. 
    func getCharacter(post: BotBooruPostItem) async {
        isLoading = true 
        let result = await botBooruService.getPost(post: post)
        switch result {
            case .success(let response):
            do {
                try await characterStore.saveCharacterCard(response)
            } catch {
                print("Failed to save from booru: \(error.localizedDescription)")
            }
            case .failure:
                print("Error getting character")
        }
        isLoading = false
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
