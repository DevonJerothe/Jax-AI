import Foundation 
import SwiftUI 

@MainActor
@Observable
final class CharacterCardsViewModel {
    private let characterStore: CharacterStore
    private let connectionManager: ConnectionStatusManager
    private let chatStore: ChatStore

    init(
        characterStore: CharacterStore? = nil,
        chatStore: ChatStore? = nil,
        connectionManager: ConnectionStatusManager? = nil
    ) {
        // Swift evaluates default arguments outside actor isolation, so the
        // shared container fallback needs to happen inside the main-actor init.
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.connectionManager = connectionManager ?? ServiceContainer.shared.getConnectionStatusManager()
        self.chatStore = chatStore ?? ServiceContainer.shared.getChatStore()
    }

    var characterCards: [CharacterCardModel] {
        guard connectionManager.connectionSettings.locked else {
            return characterStore.characters.filter { $0.isSystemChar == false }
        }

        return characterStore.characters.filter { $0.isPrivate == false && $0.isSystemChar == false }
    }

    func newChat(card: CharacterCardModel) async -> ChatModel? {
        do {
            let newChat = ChatModel(fromCard: card)
            try await chatStore.addChat(newChat)
            return newChat
        } catch {
            print("CharacterCardsViewModel: Failed to create new chat: \(error)")
            return nil
        }
    }

    func deleteCharacterCard(card: CharacterCardModel) async {
        do {
            try await characterStore.deleteCharacterCard(card)
        } catch {
            print("CharacterCardsViewModel: Failed to delete character card: \(error)")
        }
    }
}
