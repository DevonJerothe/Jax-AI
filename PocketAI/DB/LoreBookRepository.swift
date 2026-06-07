import Foundation
import GRDB

class LoreBookRepository: Repository {
    typealias T = LoreBookModel

    private let dbManager = DBManager.shared

    func observeAll() throws -> some AsyncSequence<[LoreBookModel], Error> {
        guard let writer = dbManager.dbQueue else {
            throw AppDBError.unavailable
        }

        let observer = ValueObservation.tracking { db in
            try self.fetchLoreBooks(db)
        }

        return observer.values(in: writer)
    }

    func getAll() throws -> [LoreBookModel] {
        try dbManager.read { db in
            try fetchLoreBooks(db)
        }
    }

    func get(id: UUID) throws -> LoreBookModel? {
        try dbManager.read { db in
            guard let record = try LoreBookRecord.fetchOne(db, key: id.uuidString) else {
                return nil
            }

            return try model(from: record, db: db)
        }
    }

    func save(_ item: LoreBookModel) throws {
        try dbManager.write { db in
            var record = item.record
            record.updatedAt = Date()
            try record.save(db)

            let loreBookId = item.id.uuidString
            let attachedEntryIds = item.entries.map { $0.id.uuidString }
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

            for entry in item.entries {
                var entry = entry
                entry.loreBookId = loreBookId
                var entryRecord = entry.record
                try entryRecord.save(db)
            }
        }
    }

    func delete(_ item: LoreBookModel) throws {
        try dbManager.write { db in
            guard let record = try LoreBookRecord.fetchOne(db, key: item.id.uuidString) else {
                return
            }

            try record.delete(db)
        }
    }

    private func fetchLoreBooks(_ db: Database) throws -> [LoreBookModel] {
        try LoreBookRecord
            .order(Column("updatedAt").desc)
            .fetchAll(db)
            .map { record in
                try model(from: record, db: db)
            }
    }

    private func model(from record: LoreBookRecord, db: Database) throws -> LoreBookModel {
        var loreBook = LoreBookModel(record: record)
        loreBook.entries =
            try LoreBookEntryRecord
            .filter(Column("loreBookId") == record.id)
            .order(Column("order").asc)
            .fetchAll(db)
            .map { LoreBookEntryModel(record: $0) }
        loreBook.chats = try chats(for: record.id, db: db)
        return loreBook
    }

    private func chats(for loreBookId: String, db: Database) throws -> [ChatModel] {
        let chatIds =
            try ChatLoreBookJoinRecord
            .filter(Column("loreBookId") == loreBookId)
            .fetchAll(db)
            .map { $0.chatId }

        guard chatIds.isEmpty == false else {
            return []
        }

        return
            try ChatRecord
            .filter(chatIds.contains(Column("id")))
            .fetchAll(db)
            .map { ChatModel(record: $0) }
    }
}
