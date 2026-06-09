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
                .including(optional: CharacterCardRecord.characterBook)
                .order(Column("createdAt").desc)
                .asRequest(of: CharacterCardWithChats.self)

            // fetch DTO
            let charactersWithChats = try characterRequest.fetchAll(db)

            let characters = try charactersWithChats.map { model in
                var character = CharacterCardModel(record: model.characterCard)
                character.chats = model.chats.map { ChatModel(record: $0) }

                // get associated character card entries
                if let loreBookRecord = model.characterBook {
                    var loreBook = LoreBookModel(record: loreBookRecord)
                    loreBook.entries = try LoreBookEntryRecord
                        .filter(Column("loreBookId") == loreBookRecord.id)
                        .order(Column("order").asc)
                        .fetchAll(db)
                        .map { LoreBookEntryModel(record: $0) }

                    character.characterBook = loreBook
                }
                
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
                .including(optional: CharacterCardRecord.characterBook)
                .order(Column("createdAt").desc)
                .asRequest(of: CharacterCardWithChats.self)

            // fetch DTO
            let charactersWithChats = try characterRequest.fetchAll(db)

            let characters = try charactersWithChats.map { model in
                var character = CharacterCardModel(record: model.characterCard)
                character.chats = model.chats.map { ChatModel(record: $0) }

                // get associated character card entries
                if let loreBookRecord = model.characterBook {
                    var loreBook = LoreBookModel(record: loreBookRecord)
                    loreBook.entries = try LoreBookEntryRecord
                        .filter(Column("loreBookId") == loreBookRecord.id)
                        .order(Column("order").asc)
                        .fetchAll(db)
                        .map { LoreBookEntryModel(record: $0) }

                    character.characterBook = loreBook
                }
                
                return character
            }

            return characters
        }
    }

    func get(id: UUID) throws -> CharacterCardModel? {
        try dbManager.read { db in
            let characterRequest = CharacterCardRecord
                .including(all: CharacterCardRecord.chats)
                .including(optional: CharacterCardRecord.characterBook)
                .filter(Column("id") == id.uuidString)
                .asRequest(of: CharacterCardWithChats.self)
            
            let characterWithChats = try characterRequest.fetchOne(db)
            
            let character = try characterWithChats.map { model in
                var charModel = CharacterCardModel(record: model.characterCard)
                charModel.chats = model.chats.map { ChatModel(record: $0) }

                // get associated character card entries
                if let loreBookRecord = model.characterBook {
                    var loreBook = LoreBookModel(record: loreBookRecord)
                    loreBook.entries = try LoreBookEntryRecord
                        .filter(Column("loreBookId") == loreBookRecord.id)
                        .order(Column("order").asc)
                        .fetchAll(db)
                        .map { LoreBookEntryModel(record: $0) }

                    charModel.characterBook = loreBook
                }
                
                return charModel
            }

            return character
        }
    }

    func save(_ item: CharacterCardModel) throws {
        try dbManager.write { db in
            var record = item.record
            try record.save(db)
            
            // Save any attached CharacterBook
            if var characterBook = item.characterBook {
                characterBook.characterCardId = item.id.uuidString

                var loreBookRecord = characterBook.record
                try loreBookRecord.save(db)

                let attachedEntryIds = characterBook.entries.map { $0.id.uuidString }
                let associatedEntryIds = try LoreBookEntryRecord
                    .filter(Column("loreBookId") == characterBook.id.uuidString)
                    .fetchAll(db)
                    .map { $0.id }
                let staleEntryIds = Set(associatedEntryIds).subtracting(attachedEntryIds)

                if staleEntryIds.isEmpty == false {
                    try LoreBookEntryRecord
                        .filter(Column("loreBookId") == characterBook.id.uuidString)
                        .filter(staleEntryIds.contains(Column("id")))
                        .deleteAll(db)
                }

                for entry in characterBook.entries {
                    var entry = entry
                    entry.loreBookId = characterBook.id.uuidString
                    var entryRecord = entry.record
                    try entryRecord.save(db)
                }
                
            } else {
                // Remove any associated LoreBooks
                try LoreBookRecord
                    .filter(Column("characterCardId") == item.id.uuidString)
                    .updateAll(db, Column("characterCardId").set(to: nil))
            }

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
