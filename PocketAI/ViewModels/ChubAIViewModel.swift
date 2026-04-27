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
    var searchQuery: String = "" 
    var sort: ChubSort = .defaultSort

    var chubSettings: ChubAISettings

    var hasMore: Bool = true

    init(
        characterStore: CharacterStore? = nil,
        loadCards: Bool = true
    ) {
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.chubSettings = chubAIService.chubSettings ?? ChubAISettings()
        self.excludedTopics = chubSettings.excludedTopics

        Task {
            if loadCards {
                isLoading = true
                async let cards: Void = searchCards(initLoad: true)
                async let tags: Void = getTags()
                _ = await (cards, tags)
                isLoading = false
            } else {
                await getTags()
            }
        }
    }

    func updateChubSettings(_ settings: ChubAISettings) {
        chubSettings = settings
        chubAIService.updateChubSettings(settings)
    }

    func getTags() async {
        let result = await chubAIService.getTags()
        switch result {
            case .success(let response):
                self.tags = response.tags
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
        }
    }

    func searchCards(refresh: Bool = false, initLoad: Bool = false) async {
        if isLoading {
            guard initLoad else { return }
        }
        
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
                    if initLoad == false {
                        isLoading = false
                    }
                    return
                }
                cards.append(contentsOf: nodes)
                hasMore = nodes.count == count 
            case .failure(let error): 
                print("Error: \(error.localizedDescription)")
        }
        if initLoad == false {
            isLoading = false
        }
    }

    // TODO: We should create a new page to view the card details before saving. 
    func getCharacter(card: ChubCardNode) async {
        isLoading = true 
        let result = await chubAIService.getCharacter(character: card)
        switch result {
            case .success(let response):
                do {
                    let characterCard = CharacterCardModel(fromChub: response)
                    try await characterStore.saveCharacterCard(characterCard)
                } catch {
                    print("Failed to save from chub: \(error.localizedDescription)")
                }
            case .failure(let error):
                print("Error getting character: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func loadMore() async {
        if hasMore {
            page += 1
            await searchCards()
        }
    }
}
