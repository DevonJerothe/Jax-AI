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

    var llmClient: KoboldAPI?
    var modelName: String?
    var chats: [ChatModel] = []
    var connected: Bool = false

    var showNewChatSheet: Bool = false

    func connect(_ host: String, _ port: Int) async {
        llmClient = KoboldAPI(
            urlSession: URLSession.shared,
            host: host, 
            port: port
        )

        let name = await llmClient?.getModel()
        switch name {
        case .success(let name):
            self.modelName = name
            print(name)
            self.connected = true
        case .failure(let error):
            print("Error: \(error)")
            self.connected = false
        case .none:
            self.connected = false
        }
    }

    @MainActor
    func createNewChat(chatModel: ChatModel) {
        do {
            try chatModel.save()
            chats.append(chatModel)
        } catch {
            print("Failed to save chat: \(error)")
            // Log more details about the error
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
            let allChats = try ChatModel.loadAllChats()
            print("Successfully loaded \(allChats.count) chats")
            self.chats = allChats
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
    func deleteChat(at indexSet: IndexSet) {
        for index in indexSet {
            let chatToDelete = chats[index]
            do {
                try chatToDelete.delete()
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
