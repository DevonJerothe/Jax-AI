import Foundation
import GRDB

struct ChatLoreBookJoinRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "chat_lorebook_join"

    static let chat = belongsTo(ChatRecord.self, using: ForeignKey([Column("chatId")]))
    static let loreBook = belongsTo(LoreBookRecord.self, using: ForeignKey([Column("loreBookId")]))

    var id: UUID = UUID()
    var chatId: String
    var loreBookId: String

    init(chatId: String, loreBookId: String) {
        self.chatId = chatId
        self.loreBookId = loreBookId
    }

    public static func migrateTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { builder in
            builder.column("id", .text).notNull().primaryKey()
            builder.column("chatId", .text).notNull().indexed().references(
                ChatRecord.databaseTableName, onDelete: .cascade)
            builder.column("loreBookId", .text).notNull().indexed().references(
                LoreBookRecord.databaseTableName, onDelete: .cascade)
            builder.uniqueKey(["chatId", "loreBookId"])
        }
    }
}