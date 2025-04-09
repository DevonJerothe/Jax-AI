//
//  MessageModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import Foundation
import GRDB

public enum MessageActor: Int, Codable{
    case user = 0
    case bot = 1
}

struct MessageModel: Identifiable, Hashable {
    var id: UUID = UUID()
    var chatId: String = ""
    var actor: MessageActor
    var text: String = ""
    var loading: Bool = false
    var createdAt: Date = Date()
    var exclude: Bool = false

    static let databaseTableName = "messages"

    mutating func setLoading(_ loading: Bool) {
        self.loading = loading
    }

    func getRolePlayText(cardName: String) -> String {
        // First handle straight quotes
        var processedText = text
        let straightQuotePattern = "\"([^\"]+)\""
        processedText = processedText.replacingOccurrences(
            of: straightQuotePattern,
            with: "`\"$1\"`",
            options: .regularExpression)
        
        // Then handle curly quotes - using Unicode escape sequences
        // these are usually added to user prompts when using iOS keyboard
        let curlyQuotePattern = "\u{201C}([^\u{201D}]+)\u{201D}"
        processedText = processedText.replacingOccurrences(
            of: curlyQuotePattern,
            with: "`\u{201C}$1\u{201D}`",
            options: .regularExpression)
        
        // Whenever we get the following `{user}` or `{char}` we should replace with the correct names
        processedText = processedText.replacingOccurrences(of: "{{char}}", with: cardName)
        
        // TODO: replace this with a user persona
        processedText = processedText.replacingOccurrences(of: "{{user}}", with: "Devon")
        
        return processedText
    }
}

extension MessageModel: TableRecord, FetchableRecord, PersistableRecord {
    init(row: GRDB.Row) throws {
        id = UUID(uuidString: row["id"])!
        chatId = row["chatId"]
        actor = MessageActor(rawValue: row["actor"]) ?? .bot
        text = row["text"]
        loading = row["loading"]
        exclude = row["exclude"]
        createdAt = row["createdAt"]
    }
    
    func encode(to container: inout GRDB.PersistenceContainer) {
        container["id"] = id.uuidString
        container["chatId"] = chatId
        container["actor"] = actor.rawValue
        container["text"] = text
        container["loading"] = loading
        container["exclude"] = exclude
        container["createdAt"] = createdAt
    }
}
extension MessageModel {
    public static func migrateTable(_ db: Database) throws {
        try db.create(table: "messages", ifNotExists: true) { t in
            t.column("id", .text).primaryKey().notNull()
            t.column("chatId", .text).notNull().indexed().references("chats", onDelete: .cascade)
            t.column("actor", .integer).notNull()
            t.column("text", .text).notNull()
            t.column("loading", .boolean).notNull()
            t.column("exclude", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
        }
    }
}

