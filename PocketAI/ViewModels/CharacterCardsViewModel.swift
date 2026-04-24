import Foundation 
import SwiftUI 

@MainActor
@Observable
final class CharacterCardsViewModel {
    private let characterStore: CharacterStore

    init(characterStore: CharacterStore? = nil) {
        // Swift evaluates default arguments outside actor isolation, so the
        // shared container fallback needs to happen inside the main-actor init.
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
    }

    var characterCards: [CharacterCardModel] {
        characterStore.characters
    }

    func deleteCharacterCard(card: CharacterCardModel) async {
        do {
            try await characterStore.deleteCharacterCard(card)
        } catch {
            print("CharacterCardsViewModel: Failed to delete character card: \(error)")
        }
    }
}
