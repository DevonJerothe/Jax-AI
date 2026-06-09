import Foundation 
import SwiftUI 

@MainActor
@Observable
final class CharacterCardsViewModel {
    private let characterStore: CharacterStore
    private let connectionManager: ConnectionStatusManager

    init(characterStore: CharacterStore? = nil, connectionManager: ConnectionStatusManager? = nil) {
        // Swift evaluates default arguments outside actor isolation, so the
        // shared container fallback needs to happen inside the main-actor init.
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.connectionManager = connectionManager ?? ServiceContainer.shared.getConnectionStatusManager()
    }

    var characterCards: [CharacterCardModel] {
        guard connectionManager.connectionSettings.locked else {
            return characterStore.characters
        }

        return characterStore.characters.filter { $0.isPrivate == false }
    }

    func deleteCharacterCard(card: CharacterCardModel) async {
        do {
            try await characterStore.deleteCharacterCard(card)
        } catch {
            print("CharacterCardsViewModel: Failed to delete character card: \(error)")
        }
    }
}
