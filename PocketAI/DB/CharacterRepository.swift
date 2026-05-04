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
    
    func observeAll() throws -> some AsyncSequence<[CharacterCardModel], Error> {
        guard let writer = dbManager.dbQueue else {
            throw AppDBError.unavailable
        }

        let observer = ValueObservation.tracking { db in
            let characterRequest = CharacterCardRecord
                .including(all: CharacterCardRecord.chats)
                .order(Column("createdAt").desc)
                .asRequest(of: CharacterCardWithChats.self)

            // fetch DTO
            let charactersWithChats = try characterRequest.fetchAll(db)

            let characters = charactersWithChats.map { model in
                var character = CharacterCardModel(record: model.characterCard)
                character.chats = model.chats.map { ChatModel(record: $0) }
                return character
            }

            return characters
        }

        return observer.values(in: writer)
    }

    func getAll() throws -> [CharacterCardModel] {
        try dbManager.read { db in
            let characterRequest = CharacterCardRecord
                .including(all: CharacterCardRecord.chats)
                .order(Column("createdAt").desc)
                .asRequest(of: CharacterCardWithChats.self)

            // fetch DTO
            let charactersWithChats = try characterRequest.fetchAll(db)

            let characters = charactersWithChats.map { model in
                var character = CharacterCardModel(record: model.characterCard)
                character.chats = model.chats.map { ChatModel(record: $0) }
                return character
            }

            return characters
        }
    }

    func get(id: UUID) throws -> CharacterCardModel? {
        try dbManager.read { db in
            let characterRequest = CharacterCardRecord
                .including(all: CharacterCardRecord.chats)
                .filter(Column("id") == id.uuidString)
                .asRequest(of: CharacterCardWithChats.self)
            
            let characterWithChats = try characterRequest.fetchOne(db)
            
            let character = characterWithChats.map { model in
                var charModel = CharacterCardModel(record: model.characterCard)
                charModel.chats = model.chats.map { ChatModel(record: $0) }
                return charModel
            }

            return character
        }
    }

    func save(_ item: CharacterCardModel) throws {
        try dbManager.write { db in
            var record = item.record
            try record.save(db)

            guard item.isPrivate else {
                return
            }

            try db.execute(
                sql: """
                UPDATE chats
                SET isPrivate = 1,
                    updatedAt = CURRENT_TIMESTAMP
                WHERE id IN (
                    SELECT chatId
                    FROM chat_character_join
                    WHERE characterCardId = ?
                )
                """,
                arguments: [item.id.uuidString]
            )
        }
    }

    func delete(_ item: CharacterCardModel) throws {
        try dbManager.write { db in
            guard let record = try CharacterCardRecord.fetchOne(db, key: item.id.uuidString) else {
                return
            }

            // Check for any chats associated with and only with this character. 
            // we want to delete these as well. The join record cascade will not delete them.
            let chatAlias = TableAlias()
            let chatsWithOtherAssociations = ChatCharacterJoinRecord
                .filter(Column("characterCardId") != item.id.uuidString)
                .filter(Column("chatId") == chatAlias[Column("id")])
                .exists()

            let chatsToDelete = try ChatRecord
                .aliased(chatAlias)
                .filter(
                    ChatCharacterJoinRecord
                        .filter(Column("characterCardId") == item.id.uuidString)
                        .filter(Column("chatId") == chatAlias[Column("id")])
                        .exists()
                )
                .filter(!chatsWithOtherAssociations)
                .fetchAll(db)

            try chatsToDelete.forEach { chat in
                try chat.delete(db)
            }

            try record.delete(db)
        }
    }
}
