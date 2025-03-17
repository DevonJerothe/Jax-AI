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

    func getRolePlayText() -> String {
        // First handle straight quotes
        var processedText = text
        let straightQuotePattern = "\"([^\"]+)\""
        processedText = processedText.replacingOccurrences(
            of: straightQuotePattern,
            with: "`\"$1\"`",
            options: .regularExpression)
        
        // Then handle curly quotes - using Unicode escape sequences
        let curlyQuotePattern = "\u{201C}([^\u{201D}]+)\u{201D}"
        processedText = processedText.replacingOccurrences(
            of: curlyQuotePattern,
            with: "`\u{201C}$1\u{201D}`",
            options: .regularExpression)
        
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
    func save() throws {
        try DBManager.shared.write { db in
            try self.save(db)
        }
    }

    func delete() throws {
        try DBManager.shared.write { db in
            try self.delete(db)
        }
    }
}
