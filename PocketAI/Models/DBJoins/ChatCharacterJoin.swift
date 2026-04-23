import Foundation
import GRDB
struct ChatCharacterJoinRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "chat_character_join"

    static let chat = belongsTo(ChatRecord.self, using: ForeignKey([Column("chatId")]))
    static let characterCard = belongsTo(CharacterCardRecord.self, using: ForeignKey([Column("characterCardId")]))

    var id: UUID = UUID()
    var chatId: String
    var characterCardId: String

    init(chatId: String, characterCardId: String) {
        self.chatId = chatId
        self.characterCardId = characterCardId
    }
}

extension ChatCharacterJoinRecord {
    public static func migrateTable(_ db: Database) throws {
        try db.create(table: "chat_character_join", ifNotExists: true) { t in 
            t.column("id", .text).notNull().primaryKey()
            t.column("chatId", .text).notNull().indexed().references("chats", onDelete: .cascade)
            t.column("characterCardId", .text).notNull().indexed().references("char_cards", onDelete: .cascade)

            t.uniqueKey(["chatId", "characterCardId"])
        }
    }
}
