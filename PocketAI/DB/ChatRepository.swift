import Foundation
import GRDB

class ChatRepository: Repository {
    typealias T = ChatModel

    private let dbManager = DBManager.shared

    /// Auto listen for any DB changes for chars / chats / and messages. Call from a store or shared location where a single
    /// in memory array can be source of truth.
    ///
    /// TODO: returning all messages on all chats can become expensive here. We should limit it to one so we have the
    /// lat message in our cell view, then observe the messages seperatly once in the chat view.
    func observeAll() throws -> some AsyncSequence<[ChatModel], Error> {
        guard let writer = dbManager.dbQueue else {
            throw AppDBError.unavailable
        }

        let observer = ValueObservation.tracking { db in
            try self.fetchChats(db)
        }
        return observer.values(in: writer)

    }

    func getAll() throws -> [ChatModel] {
        try dbManager.read { db in
            try fetchChats(db)
        }
    }

    private func allChatsRequest() -> QueryInterfaceRequest<ChatWithCharacterCards> {
        ChatRecord
            .including(all: ChatRecord.characterCards)
            .including(all: ChatRecord.loreBooks)
            .including(all: ChatRecord.messages.order(Column("createdAt").asc))
            .order(Column("updatedAt").desc)
            .asRequest(of: ChatWithCharacterCards.self)
    }

    private func fetchChats(_ db: Database) throws -> [ChatModel] {
        try allChatsRequest().fetchAll(db).map { model in
            var chat = ChatModel(record: model.chat)
            chat.characterCards = model.characterCards.map { CharacterCardModel(record: $0) }
            chat.loreBooks = try model.loreBooks.map { loreBookRecord in
                var loreBook = LoreBookModel(record: loreBookRecord)
                loreBook.entries =
                    try LoreBookEntryRecord
                    .filter(Column("loreBookId") == loreBookRecord.id)
                    .order(Column("order").asc)
                    .fetchAll(db)
                    .map { LoreBookEntryModel(record: $0) }
                return loreBook
            }
            chat.messages = model.messages.map { MessageModel(record: $0) }
            return chat
        }
    }

    func save(_ item: ChatModel) throws {
        try dbManager.write { db in
            let chatId = item.id.uuidString

            try saveChatRecord(item, db)
            try saveCharacterCards(item.characterCards, db)
            try syncChatCharacterJoins(chatId: chatId, characterCards: item.characterCards, db)

            try saveLoreBooks(item.loreBooks, db)
            try syncChatLoreBookJoins(chatId: chatId, loreBooks: item.loreBooks, db)

            try markChatsPrivateForPrivateCharacters(item.characterCards, db)
        }
    }

    func delete(_ item: ChatModel) throws {
        try dbManager.write { db in
            guard let record = try ChatRecord.fetchOne(db, key: item.id.uuidString) else {
                return
            }

            try record.delete(db)
        }
    }
}

private extension ChatRepository {
    func saveChatRecord(_ item: ChatModel, _ db: Database) throws {
        var record = item.record
        record.isPrivate = item.isPrivate || item.characterCards.contains(where: \.isPrivate)
        record.updatedAt = Date()
        try record.save(db)
    }

    func saveCharacterCards(_ characterCards: [CharacterCardModel], _ db: Database)
        throws
    {
        for characterCard in characterCards {
            var record = characterCard.record
            try record.save(db)
        }
    }

    func saveLoreBooks(_ loreBooks: [LoreBookModel], _ db: Database) throws {
        for loreBook in loreBooks {
            var loreBookRecord = loreBook.record
            loreBookRecord.updatedAt = Date()
            try loreBookRecord.save(db)

            try syncLoreBookEntries(
                loreBook.entries,
                loreBookId: loreBook.id.uuidString,
                db
            )
        }
    }

    func syncLoreBookEntries(
        _ entries: [LoreBookEntryModel],
        loreBookId: String,
        _ db: Database
    ) throws {
        let attachedEntryIds = entries.map { $0.id.uuidString }
        let associatedEntryIds =
            try LoreBookEntryRecord
            .filter(Column("loreBookId") == loreBookId)
            .fetchAll(db)
            .map { $0.id }
        let staleEntryIds = Set(associatedEntryIds).subtracting(attachedEntryIds)

        if staleEntryIds.isEmpty == false {
            try LoreBookEntryRecord
                .filter(Column("loreBookId") == loreBookId)
                .filter(staleEntryIds.contains(Column("id")))
                .deleteAll(db)
        }

        for entry in entries {
            var entry = entry
            entry.loreBookId = loreBookId
            var entryRecord = entry.record
            try entryRecord.save(db)
        }
    }

    func syncChatCharacterJoins(
        chatId: String,
        characterCards: [CharacterCardModel],
        _ db: Database
    ) throws {
        try syncJoinRecords(
            ChatCharacterJoinRecord.self,
            db: db,
            sourceColumn: Column("chatId"),
            sourceId: chatId,
            targetColumn: Column("characterCardId"),
            targetIds: characterCards.map { $0.id.uuidString },
            getTargetId: { $0.characterCardId },
            makeRecord: { characterCardId in
                ChatCharacterJoinRecord(chatId: chatId, characterCardId: characterCardId)
            }
        )
    }

    func syncChatLoreBookJoins(
        chatId: String,
        loreBooks: [LoreBookModel],
        _ db: Database
    ) throws {
        try syncJoinRecords(
            ChatLoreBookJoinRecord.self,
            db: db,
            sourceColumn: Column("chatId"),
            sourceId: chatId,
            targetColumn: Column("loreBookId"),
            targetIds: loreBooks.map { $0.id.uuidString },
            getTargetId: { $0.loreBookId },
            makeRecord: { loreBookId in
                ChatLoreBookJoinRecord(chatId: chatId, loreBookId: loreBookId)
            }
        )
    }

    func syncJoinRecords<Record: FetchableRecord & MutablePersistableRecord>(
        _ recordType: Record.Type,
        db: Database,
        sourceColumn: Column,
        sourceId: String,
        targetColumn: Column,
        targetIds: [String],
        getTargetId: (Record) -> String,
        makeRecord: (String) -> Record
    ) throws {
        let associatedIds =
            try recordType
            .filter(sourceColumn == sourceId)
            .fetchAll(db)
            .map(getTargetId)

        let attachedIds = Set(targetIds)
        let staleIds = Set(associatedIds).subtracting(attachedIds)
        let newIds = attachedIds.subtracting(associatedIds)

        if staleIds.isEmpty == false {
            try recordType
                .filter(sourceColumn == sourceId)
                .filter(staleIds.contains(targetColumn))
                .deleteAll(db)
        }

        for targetId in newIds {
            var record = makeRecord(targetId)
            try record.save(db)
        }
    }

    func markChatsPrivateForPrivateCharacters(
        _ characterCards: [CharacterCardModel],
        _ db: Database
    ) throws {
        let privateCharacterIds =
            characterCards
            .filter(\.isPrivate)
            .map { $0.id.uuidString }

        guard privateCharacterIds.isEmpty == false else {
            return
        }

        let placeholders = Array(repeating: "?", count: privateCharacterIds.count).joined(
            separator: ",")

        try db.execute(
            sql: """
                UPDATE chats
                SET isPrivate = 1,
                    updatedAt = CURRENT_TIMESTAMP
                WHERE id IN (
                    SELECT chatId
                    FROM chat_character_join
                    WHERE characterCardId IN (\(placeholders))
                )
                """,
            arguments: StatementArguments(privateCharacterIds)
        )
    }
}
