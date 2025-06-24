import Foundation
import GRDB

struct ChatCharacterJoin: FetchableRecord, PersistableRecord {

    var id: UUID = UUID() 
    var chatId: String 
    var characterCardId: String

    static let databaseTableName = "chat_character_join"
    
    init(
        chatId: String,
        characterCardId: String
    ) {
        self.chatId = chatId
        self.characterCardId = characterCardId
    }
    
    init(row: Row) throws {
        id = UUID(uuidString: row["id"]!)!
        chatId = row["chatId"]
        characterCardId = row["charCardId"]
    }
    
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id.uuidString
        container["chatId"] = chatId
        container["charCardId"] = characterCardId
    }

    public static func migrateTable(_ db: Database) throws {
        try db.create(table: "chat_character_join", ifNotExists: true) { t in
            t.column("id", .text).primaryKey().notNull()
            t.column("chatId", .text).notNull().indexed().references("chats", onDelete: .cascade)
            t.column("charCardId", .text).notNull().indexed().references("char_cards", onDelete: .cascade)
            
            t.uniqueKey(["chatId", "charCardId"])
        }
    }
}
