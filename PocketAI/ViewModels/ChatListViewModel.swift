//
//  ChatListViewModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import Foundation
import SwiftUI
import SwiftLLMSDK
import GRDB

@Observable
class ChatListViewModel {
    private let chatRepository: ChatRepository
    private let characterRepository: CharacterRepository
    private var serviceContainer = ServiceContainer.shared

    var modelName: String?
    var chats: [ChatModel] = []
    var characterCards: [CharacterCardModel] = []
    var connected: Bool = false
    var showNewChatSheet: Bool = false
    var showConnectionSheet: Bool = false

    init(
        chatRepository: ChatRepository = ServiceContainer.shared.getChatRepository(),
        characterRepository: CharacterRepository = ServiceContainer.shared.getCharacterRepository()
    ) {
        self.chatRepository = chatRepository
        self.characterRepository = characterRepository
    }

    @MainActor
    func refreshData() {
        print("ChatListViewModel: refreshData() called")
        // Force reload data from database to ensure we have the latest changes
        self.chats = []
        self.characterCards = []
        loadChats()
        loadCharacterCards()
        print("ChatListViewModel: refreshData() completed")
    }

    @MainActor
    func updateChatInList(_ updatedChat: ChatModel) {
        // Find and update the specific chat in our local array
        if let index = chats.firstIndex(where: { $0.id == updatedChat.id }) {
            chats[index] = updatedChat
        }
    }

    @MainActor
    func createNewChat(chatModel: ChatModel) {
        do {
            try chatRepository.save(chatModel)
            chats.append(chatModel)
        } catch {
            print("Failed to save chat: \(error)")
            if let dbError = error as? GRDB.DatabaseError {
                print("Database error code: \(dbError.resultCode), message: \(dbError.message ?? "No message")")
                print("SQL: \(dbError.sql ?? "No SQL")")
                print("Description: \(dbError.description)")
            }
        }
    }

    @MainActor
    func loadChats() {
        do {
            print("ChatListViewModel: Loading chats from database...")
            let freshChats = try chatRepository.getAll()
            print("ChatListViewModel: Loaded \(freshChats.count) chats from database")
            
            // Log message counts for debugging
            for (index, chat) in freshChats.enumerated() {
                print("ChatListViewModel: Chat \(index): '\(chat.chatTitle)' has \(chat.messages.count) messages")
            }
            
            self.chats = freshChats
            print("ChatListViewModel: Updated local chats array")
        } catch {
            print("ChatListViewModel: Failed to load chats: \(error)")
            if let dbError = error as? GRDB.DatabaseError {
                print("Database error code: \(dbError.resultCode), message: \(dbError.message ?? "No message")")
                print("SQL: \(dbError.sql ?? "No SQL")")
                print("Description: \(dbError.description)")
            }
        }
    }

    @MainActor
    func loadCharacterCards() {
        do {
            print("ChatListViewModel: Loading character cards from database...")
            self.characterCards = try characterRepository.getAll()
            print("ChatListViewModel: Loaded \(self.characterCards.count) character cards")
        } catch {
            print("ChatListViewModel: Failed to load character cards: \(error)")
        }
    }
    
    @MainActor
    func deleteChat(at indexSet: IndexSet) {
        for index in indexSet {
            let chatToDelete = chats[index]
            do {
                try chatRepository.delete(chatToDelete)
                chats.remove(at: index)
            } catch {
                print("Failed to delete chat: \(error)")
                if let dbError = error as? GRDB.DatabaseError {
                    print("Database error code: \(dbError.resultCode), message: \(dbError.message ?? "No message")")
                    print("SQL: \(dbError.sql ?? "No SQL")")
                    print("Description: \(dbError.description)")
                }
            }
        }
    }
}
