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

struct TextGenerationHistory: Codable, Sendable, Hashable {
    let text: String
    let tokenCount: Int
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

    // Text generations and their token counts 
    var textGenerationHistory: [TextGenerationHistory] = []
    
    // model name for the last token count call. 
    // changing models may change tokenizer, so we should invalidate old token counts.
    var tokenCountModel: String? 
    
    var status: MessageStatus = .done

    func getRolePlayText(cardName: String, personaName: String) -> String {
        MessageDisplayFormatter.rolePlayText(for: self, characterName: cardName, userName: personaName)
    }
}

// Message generation functions \
extension MessageModel {
    var generationPosition: Int? {
        guard textGenerationHistory.isEmpty == false else {
            return nil
        }

        if let currentIndex = textGenerationHistory.lastIndex(where: { $0.text == text }) {
            return currentIndex + 1
        }

        return textGenerationHistory.count + 1
    }

    var generationCount: Int {
        guard textGenerationHistory.isEmpty == false else {
            return 1
        }

        if textGenerationHistory.contains(where: { $0.text == text }) {
            return textGenerationHistory.count
        }

        return textGenerationHistory.count + 1
    }

    func hasMoreGenerations(before: Bool) -> Bool {
        // check if our generation history is empty
        if textGenerationHistory.isEmpty {
            return false
        }
        
        if before {
            let currentIndex = textGenerationHistory.lastIndex(where: { $0.text == text })
            // If we dont get a match but we have history, we can assume this generation is the most current
            if currentIndex == nil {
                return true
            }
            
            // make sure we have a previous generation to move to
            guard let currentIndex = currentIndex, currentIndex > 0 else {
                return false
            }
            return true
        } else {
            guard let currentIndex = textGenerationHistory.lastIndex(where: { $0.text == text }) else {
                return false
            }
            
            // make sure we have a next generation to move to
            return currentIndex + 1 < textGenerationHistory.count
        }
    }

    mutating func addNewGeneration() {
        guard text.isEmpty == false else {
            return
        }

        let generation = TextGenerationHistory(text: text, tokenCount: tokenCount)
        if textGenerationHistory.contains(generation) == false {
            textGenerationHistory.append(generation)
        }
    }

    mutating func updateCurrentGeneration(text newText: String, tokenCount newTokenCount: Int) {
        if let currentIndex = textGenerationHistory.lastIndex(where: { $0.text == text }) {
            textGenerationHistory[currentIndex] = TextGenerationHistory(
                text: newText,
                tokenCount: newTokenCount
            )
        }

        text = newText
        tokenCount = newTokenCount
    }
    
    mutating func nextGeneration() {
        // get current index 
        guard let currentIndex = textGenerationHistory.lastIndex(where: { $0.text == text }) else {
            return
        }

        // make sure we have a next generation to move to
        guard currentIndex + 1 < textGenerationHistory.count else {
            return
        }

        // remove current text and token count, and move to next generation
        text = textGenerationHistory[currentIndex + 1].text
        tokenCount = textGenerationHistory[currentIndex + 1].tokenCount
    }

    mutating func previousGeneration() {
        // get current index if no index is found we are on the last generation, so append then move
        var currentIndex = textGenerationHistory.lastIndex(where: { $0.text == text })
        if currentIndex == nil {
            addNewGeneration()
            currentIndex = textGenerationHistory.indices.last
        }

        // make sure we have a previous generation to move to
        guard let currentIndex = currentIndex, currentIndex - 1 >= 0 else {
            return
        }

        // remove current text and token count, and move to previous generation
        text = textGenerationHistory[currentIndex - 1].text
        tokenCount = textGenerationHistory[currentIndex - 1].tokenCount
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
        self.tokenCountModel = record.tokenCountModel

        if let jsonData = record.textGenerationHistoryJSON?.data(using: .utf8), 
            let decodedHistory = try? JSONDecoder().decode([TextGenerationHistory].self, from: jsonData) {
            textGenerationHistory = decodedHistory
        }
    }

    var record: MessageRecord {
        let jsonData = try? JSONEncoder().encode(textGenerationHistory)
        let textGenerationHistoryJson = jsonData.flatMap { String(data: $0, encoding: .utf8) }
        
        return MessageRecord(
            id: id.uuidString,
            chatId: chatId,
            actor: actor.rawValue,
            text: text,
            exclude: exclude,
            error: error.rawValue,
            createdAt: createdAt,
            tokenCount: tokenCount,
            tokenCountModel: tokenCountModel,
            textGenerationHistoryJSON: textGenerationHistoryJson
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
    var tokenCountModel: String?
    var textGenerationHistoryJSON: String?

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
            t.column("tokenCountModel", .text)
            t.column("textGenerationHistoryJSON", .text)
        }
    }
}
