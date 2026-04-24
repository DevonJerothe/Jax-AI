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

    var showNewChatSheet: Bool = false
    var showConnectionSheet: Bool = false

    init(chatStore: ChatStore? = nil, characterStore: CharacterStore? = nil) {
        self.chatStore = chatStore ?? ServiceContainer.shared.getChatStore()
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
    }

    var chats: [ChatModel] {
        chatStore.chats
    }

    var characterCards: [CharacterCardModel] {
        characterStore.characters
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
