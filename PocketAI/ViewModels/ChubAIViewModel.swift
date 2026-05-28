import SwiftUI 
import SwiftLLMSDK

@MainActor
@Observable
final class ChubAIViewModel {
    private let characterStore: CharacterStore
    private let chubAIService: ChubService = .init()

    var cards: [ChubCardNode] = []
    var tags: [ChubAITag] = []
    var excludedTopics: [ChubAITag] = []
    var selectedTopics: [ChubAITag] = []
    var page: Int = 1
    var count: Int = 20
    var isLoading: Bool = false 
    var tagsLoading: Bool = false
    var loggedIn: Bool = false
    var loginError: String = ""
    var searchQuery: String = "" 
    var sort: ChubSort = .defaultSort

    var chubSettings: ChubAISettings
    private var isLoadingTags: Bool = false

    var hasMore: Bool = true

    init(
        characterStore: CharacterStore? = nil,
        loadCards: Bool = true
    ) {
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.chubSettings = chubAIService.chubSettings ?? ChubAISettings()
        self.excludedTopics = chubSettings.excludedTopics

        loggedIn = self.chubSettings.apiKey != nil

        if loggedIn {
            if let lastFetched = self.chubSettings.lastFetched, Date().timeIntervalSince(lastFetched) > 24 * 60 * 60 {
                guard let username = self.chubSettings.userName, let password = self.chubSettings.password else { return }
                Task {
                    await login(username: username, password: password)
                }
            }

            if loadCards {
                Task {
                    await searchCards()
                } 
            }
        }

        // Task {
        //     isLoading = true
        //     await searchCards(initLoad: true)
        //     isLoading = false
        // }
    }

    func refreshLogin() async {
        guard let username = self.chubSettings.userName, let password = self.chubSettings.password else { return }
        await login(username: username, password: password)
    }

    func login(username: String, password: String) async {
        isLoading = true 
        loginError = "" 
        let result = await chubAIService.login(username: username, password: password)
        switch result {
            case .success: 
                chubSettings = chubAIService.chubSettings ?? chubSettings
                loggedIn = true
                await searchCards()
            case .failure(let _):
                loginError = "Invalid credentials"
                loggedIn = false 
        }
        isLoading = false 
    }

    func logout() {
        chubSettings = ChubAISettings()
        chubAIService.updateChubSettings(chubSettings)
        loggedIn = false
        cards = []
    }

    func updateChubSettings(_ settings: ChubAISettings) {
        chubSettings = settings
        chubAIService.updateChubSettings(settings)
        Task { await getTags(forceRefresh: true) }
    }

    func getTags(forceRefresh: Bool = false) async {
        if isLoadingTags || (!forceRefresh && tags.isEmpty == false) {
            return
        }

        isLoadingTags = true
        defer { isLoadingTags = false }

        let result = await chubAIService.getTags()
        switch result {
            case .success(let response):
                self.tags = response.tags
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
        }
        isLoadingTags = false
    }

    func searchCards(refresh: Bool = false) async {
        guard isLoading == false else { return }
        isLoading = true

        if refresh {
            hasMore = true
            cards = []
            page = 1
        }

        let result = await chubAIService.searchCharacters(
            query: searchQuery, 
            sort: sort, 
            page: page, 
            topics: selectedTopics.map(\.name)
        )

        switch result {
            case .success(let response): 
                guard let nodes = response.nodes else {
                    hasMore = false
                    // if initLoad == false {
                    //     isLoading = false
                    // }
                    isLoading = false
                    return
                }
                cards.append(contentsOf: nodes)
                hasMore = nodes.count == count 
            case .failure(let error):
                cards = []
                hasMore = false
                print("Error: \(error.localizedDescription)")
        }
        // if initLoad == false {
        //     isLoading = false
        // }
        isLoading = false
    }

    func getCharacter(card: ChubCardNode) async -> CharacterCardModel? {
        isLoading = true 
        let result = await chubAIService.getCharacter(character: card)
        defer { isLoading = false }

        switch result {
            case .success(let response):
                return CharacterCardModel(fromChub: response)
            case .failure(let error):
                print("Error getting character: \(error.localizedDescription)")
                return nil
        }
    }

    func loadMore() async {
        if hasMore {
            page += 1
            await searchCards()
        }
    }
}
