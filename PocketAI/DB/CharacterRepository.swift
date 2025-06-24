//
//  CharacterRepository.swift
//  PocketAI
//
//  Created by devon jerothe on 3/19/25.
//

import Foundation
import GRDB
import SwiftLLMSDK

class CharacterRepository: Repository {
    typealias T = CharacterCardModel

    private let dbManager = DBManager.shared

    func getAll() throws -> [CharacterCardModel] {
        try dbManager.read { db in

            var characters = try CharacterCardModel.fetchAll(db)

            // Fetch all chats for each character
            for i in 0..<characters.count {
                let characterId = characters[i].id.uuidString
                let chatIds = try ChatCharacterJoin
                    .filter(Column("charCardId") == characterId)
                    .fetchAll(db)
                    .map { $0.chatId }

                characters[i].chats = chatIds
            }
            
            return characters
        }
    }

    func save(_ item: CharacterCardModel) throws {
        _ = try dbManager.write { db in 
            try item.save(db)
        }
    }

    func delete(_ item: CharacterCardModel) throws {
        _ = try dbManager.write { db in 
            try item.delete(db)
        }
    }
}
