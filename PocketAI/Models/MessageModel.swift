//
//  MessageModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import Foundation
import GRDB

public enum MessageStatus: Int, Codable {
    case loading = 0
    case thinking = 1
    case streaming = 2 // used for continuation as well
    case done = 3
}

public enum MessageActor: Int, Codable{
    case user = 0
    case bot = 1
}

public enum MessageError: Int, Codable {
    case none = 0
    case apiError = 1
    case disconnect = 2
}

struct MessageModel: Identifiable, Hashable {
    var id: UUID = UUID()
    var chatId: String = ""
    var actor: MessageActor
    var text: String = ""
    var createdAt: Date = Date()
    var exclude: Bool = false
    var error: MessageError = .none
    var tokenCount: Int = 0
    
    var status: MessageStatus = .loading

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

extension MessageModel {
    init(record: MessageRecord) {
        self.id = UUID(uuidString: record.id) ?? UUID()
        self.chatId = record.chatId
        self.actor = MessageActor(rawValue: record.actor) ?? .bot
        self.text = record.text
        self.exclude = record.exclude
        self.error = MessageError(rawValue: record.error) ?? .none
        self.createdAt = record.createdAt
        self.tokenCount = record.tokenCount
    }

    var record: MessageRecord {
        MessageRecord(
            id: id.uuidString,
            chatId: chatId,
            actor: actor.rawValue,
            text: text,
            exclude: exclude,
            error: error.rawValue,
            createdAt: createdAt,
            tokenCount: tokenCount
        )
    }
}

struct MessageRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "messages"
    
    static let chat = belongsTo(ChatRecord.self, using: ForeignKey([Column("chatId")]))

    var id: String 
    var chatId: String 
    var actor: Int 
    var text: String 
    var exclude: Bool
    var error: Int 
    var createdAt: Date 
    var tokenCount: Int 

    public static func migrateTable(_ db: Database) throws {
        try db.create(table: "messages", ifNotExists: true) { t in
            t.column("id", .text).primaryKey().notNull()
            t.column("chatId", .text).notNull().indexed().references("chats", onDelete: .cascade)
            t.column("actor", .integer).notNull()
            t.column("text", .text).notNull()
            t.column("exclude", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            t.column("error", .integer).notNull().defaults(to: 0)
            t.column("tokenCount", .integer).notNull().defaults(to: 0)
        }
    }
}
