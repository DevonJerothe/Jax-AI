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
    func loadViewData() {
        loadCharacterCards()
        loadChats()
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
            print("Loading chats from database...")
            self.chats = try chatRepository.getAll()
        } catch {
            print("Failed to load chats: \(error)")
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
            print("Loading character cards from database...")
            self.characterCards = try characterRepository.getAll()
        } catch {
            print("Failed to load character cards: \(error)")
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
