import SwiftLLMSDK
import SwiftUI 

@MainActor
@Observable
final class CharHubViewModel {
    private let characterStore: CharacterStore
    private let charArchiveService: CharArchiveService = CharArchiveService()
    private var lastLoadTime: Date = .distantPast
    private var currentQuery: String = ""
    private var loadedUpToPage: Int = 0

    var randomCharacters: [CharHubModel] = []
    var latestCharacters: [CharHubModel] = []
    var searchResults: [CharHubModel] = []
    var searchQuery: String = ""
    var searchPage: Int = 1
    var searchCount: Int = 20
    var searchTotalPages: Int = 1
    var isLoading: Bool = false

    init(characterStore: CharacterStore? = nil) {
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
    }

    func getRandomCharacters() async {
        isLoading = true 
        let result = await charArchiveService.getRandomCharacters()

        switch result {
        case .success(let characters):
            randomCharacters = characters
        case .failure(let error):
            print("Error getting random characters: \(error)")
        }
        isLoading = false 
    }

    func getLatestCharacters() async {
        isLoading = true 
        let result = await charArchiveService.getLatestCharacters()

        switch result {
        case .success(let characters):
            latestCharacters = characters
        case .failure(let error):
            print("Error getting latest characters: \(error)")
        }
        isLoading = false 
    }

    func getCharacter(card: CharHubModel) async -> Bool{
        guard let path = card.path, let source = card.source else { return false }

        let result = await charArchiveService.getCharacter(path: path, source: source)

        switch result {
            case .success(var character): 
                character.cardTagline = card.tagline
                do {

                    if let thumbnail = card.thumbnail {
                        let imgData = try await charArchiveService.getData(url: thumbnail)
                        character.imageData = imgData
                    }

                    try await characterStore.saveCharacterCard(character)
                    return true
                } catch {
                    print("Error saving character: \(error)")
                    return false
                }
            case .failure(let error): 
                print("Error getting character: \(error)")
                return false
        }
    }

    func searchCharacters(query: String, page: Int, count: Int) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        // Reset when new query or first page
        if page == 1 || trimmedQuery != currentQuery {
            searchResults = []
            searchTotalPages = 1
            loadedUpToPage = 0
            currentQuery = trimmedQuery
        }

        // Prevent overlap/duplicates
        if isLoading { return }
        if trimmedQuery == currentQuery && page <= loadedUpToPage { return }

        isLoading = true

        // update state for current search
        searchQuery = trimmedQuery
        searchPage = page
        searchCount = count

        print("searching page: \(page)")

        let result = await charArchiveService.searchCharacters(query: trimmedQuery, page: page, count: count)

        switch result {
        case .success(let payload):
            let newItems = payload.result ?? []
            if page == 1 {
                searchResults = newItems
            } else {
                searchResults.append(contentsOf: newItems)
            }
            searchTotalPages = max(1, payload.totalPages ?? 1)
            loadedUpToPage = max(loadedUpToPage, page)
        case .failure(let error):
            print("Error searching characters: \(error)")
        }

        isLoading = false
    }

    func canLoadMore() -> Bool {
        return !isLoading && !searchQuery.isEmpty && loadedUpToPage < searchTotalPages
    }

    func loadNextPageIfPossible() async {
        guard canLoadMore(), Date().timeIntervalSince(lastLoadTime) > 0.5 else { return }
        
        lastLoadTime = Date()
        
        let nextPage = max(1, loadedUpToPage + 1)
        await searchCharacters(query: currentQuery.isEmpty ? searchQuery : currentQuery, page: nextPage, count: searchCount)
    }

}
