//
//  ChatListViewModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatListViewModel {
    private let chatStore: ChatStore
    private let characterStore: CharacterStore
    private let connectionManager: ConnectionStatusManager

    var showNewChatSheet: Bool = false
    var showConnectionSheet: Bool = false

    init(
        chatStore: ChatStore? = nil,
        characterStore: CharacterStore? = nil,
        connectionManager: ConnectionStatusManager? = nil
    ) {
        self.chatStore = chatStore ?? ServiceContainer.shared.getChatStore()
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.connectionManager = connectionManager ?? ServiceContainer.shared.getConnectionStatusManager()
    }

    var chats: [ChatModel] {
        guard connectionManager.connectionSettings.locked else {
            return chatStore.chats
        }

        return chatStore.chats.filter { $0.isPrivate == false }
    }

    var characterCards: [CharacterCardModel] {
        guard connectionManager.connectionSettings.locked else {
            return characterStore.characters
        }

        return characterStore.characters.filter { $0.isPrivate == false }
    }

    func createNewChat(fromCharacter: CharacterCardModel) async -> ChatModel? {
        do {
            let newChat = ChatModel(fromCard: fromCharacter)
            try await chatStore.addChat(newChat)
            return newChat
        } catch {
            print("Failed to save chat: \(error)")
            return nil
        }
    }
    
    func deleteChat(at indexSet: IndexSet) async {
        for index in indexSet {
            let chatToDelete = chats[index]
            do {
                try await chatStore.deleteChat(chatToDelete)
            } catch {
                print("Failed to delete chat: \(error)")
            }
        }
    }
}
