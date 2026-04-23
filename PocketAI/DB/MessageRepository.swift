import GRDB
import Foundation

class MessageRepository: Repository {
    typealias T = MessageModel

    private let dbManager = DBManager.shared

    func getAll() throws -> [MessageModel] {
        try dbManager.read { db in
            let messagesRequest = try MessageRecord
                .order(Column("createdAt").asc)
                .fetchAll(db)
            
            return messagesRequest.map(MessageModel.init(record:))
        }
    }

    func save(_ item: MessageModel) throws {
        // we should update chat record updateAt any time a new message is added or updated
        try dbManager.write { db in
            var record = item.record
            var chatRecord = try ChatRecord.fetchOne(db, key: record.chatId)
            chatRecord?.updatedAt = Date()
            try chatRecord?.save(db)
            try record.save(db)
        }
    }

    func delete(_ item: MessageModel) throws {
        try dbManager.write { db in
            guard let record = try MessageRecord.fetchOne(db, key: item.id.uuidString) else { return }
            
            try record.delete(db)
        }
    }
}
