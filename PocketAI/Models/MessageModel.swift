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
    case streaming = 2  // used for continuation as well
    case done = 3
}

public enum MessageActor: Int, Codable {
    case user = 0
    case bot = 1
}

public enum MessageError: Int, Codable, Sendable {
    case none = 0
    case apiError = 1
    case disconnect = 2
}

struct TextGenerationHistory: Codable, Sendable, Hashable {
    let text: String
    let tokenCount: Int
    var error: MessageError = .none
    var errorTitle: String?
    var errorMessage: String?
    var errorRecoverySuggestion: String?

    init(
        text: String,
        tokenCount: Int,
        error: MessageError = .none,
        errorTitle: String? = nil,
        errorMessage: String? = nil,
        errorRecoverySuggestion: String? = nil
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.error = error
        self.errorTitle = errorTitle
        self.errorMessage = errorMessage
        self.errorRecoverySuggestion = errorRecoverySuggestion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        tokenCount = try container.decode(Int.self, forKey: .tokenCount)
        error = try container.decodeIfPresent(MessageError.self, forKey: .error) ?? .none
        errorTitle = try container.decodeIfPresent(String.self, forKey: .errorTitle)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        errorRecoverySuggestion = try container.decodeIfPresent(
            String.self,
            forKey: .errorRecoverySuggestion
        )
    }
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
        MessageDisplayFormatter.rolePlayText(
            for: self, characterName: cardName, userName: personaName)
    }
}

// Message generation functions \
extension MessageModel {
    var generationPosition: Int? {
        guard textGenerationHistory.isEmpty == false else {
            return nil
        }

        if let currentIndex = currentGenerationHistoryIndex {
            return currentIndex + 1
        }

        return textGenerationHistory.count + 1
    }

    var generationCount: Int {
        guard textGenerationHistory.isEmpty == false else {
            return 1
        }

        if currentGenerationHistoryIndex != nil {
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
            let currentIndex = currentGenerationHistoryIndex
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
            guard let currentIndex = currentGenerationHistoryIndex else {
                return false
            }

            // make sure we have a next generation to move to
            return currentIndex + 1 < textGenerationHistory.count
        }
    }

    /// Stores the current generation as a history entry, or replaces the current
    /// slot if it is an errored generation being retried.
    ///
    /// Errored generations are never persisted as permanent history. A retry
    /// (regenerate/continue on an errored generation) replaces the errored slot
    /// in place rather than creating a new generation entry.
    mutating func addNewGeneration() {
        // If the current generation has an error, we are retrying it: replace the
        // errored slot in place instead of appending a new history entry.
        if error != .none, let erroredIndex = currentGenerationHistoryIndex {
            textGenerationHistory[erroredIndex] = TextGenerationHistory(
                text: text,
                tokenCount: tokenCount,
                error: .none
            )
            return
        }

        guard shouldStoreCurrentGeneration else {
            return
        }

        let generation = currentGenerationHistory
        if textGenerationHistory.contains(generation) == false {
            textGenerationHistory.append(generation)
        }
    }

    mutating func updateCurrentGeneration(text newText: String, tokenCount newTokenCount: Int) {
        if let currentIndex = currentGenerationHistoryIndex {
            textGenerationHistory[currentIndex] = TextGenerationHistory(
                text: newText,
                tokenCount: newTokenCount
            )
        }

        text = newText
        tokenCount = newTokenCount
        error = .none
    }

    /// Updates the error state of the current generation slot.
    ///
    /// The current generation's error metadata (title, message, recovery
    /// suggestion) is always persisted in its history slot so it survives a save
    /// and is available to `activeGenerationError` / `ChatBubbleView`. If no slot
    /// exists yet for the current generation (e.g. a fresh bot reply, or a
    /// regenerate after text was cleared), one is created here for the current
    /// (unsaved) generation. This slot is replaced in place on retry
    /// (`addNewGeneration`) and cleared on success (`updateCurrentGeneration`),
    /// so errored generations never accumulate as duplicate history entries.
    mutating func updateCurrentGenerationError(
        _ newError: MessageError,
        title: String?,
        message: String?,
        recoverySuggestion: String?
    ) {
        error = newError

        if let currentIndex = currentGenerationHistoryIndex {
            textGenerationHistory[currentIndex].error = newError
            textGenerationHistory[currentIndex].errorTitle = newError == .none ? nil : title
            textGenerationHistory[currentIndex].errorMessage = newError == .none ? nil : message
            textGenerationHistory[currentIndex].errorRecoverySuggestion =
                newError == .none ? nil : recoverySuggestion
            return
        }

        // No matching slot for the current generation yet. Create one carrying
        // the error metadata so it is persisted and available to the inline
        // error banner. Clearing a non-existent error is a no-op.
        guard newError != .none else {
            return
        }

        textGenerationHistory.append(
            TextGenerationHistory(
                text: text,
                tokenCount: tokenCount,
                error: newError,
                errorTitle: title,
                errorMessage: message,
                errorRecoverySuggestion: recoverySuggestion
            )
        )
    }

    mutating func nextGeneration() {
        // get current index
        guard let currentIndex = currentGenerationHistoryIndex else {
            return
        }

        // make sure we have a next generation to move to
        guard currentIndex + 1 < textGenerationHistory.count else {
            return
        }

        // remove current text and token count, and move to next generation
        text = textGenerationHistory[currentIndex + 1].text
        tokenCount = textGenerationHistory[currentIndex + 1].tokenCount
        error = textGenerationHistory[currentIndex + 1].error
    }

    mutating func previousGeneration() {
        // If the current generation is an unsaved errored generation, don't
        // store it — navigate directly to the last history entry. Errored
        // generations are transient and never become permanent history.
        if error != .none, currentGenerationHistoryIndex == nil {
            guard let lastIndex = textGenerationHistory.indices.last else {
                return
            }
            text = textGenerationHistory[lastIndex].text
            tokenCount = textGenerationHistory[lastIndex].tokenCount
            error = textGenerationHistory[lastIndex].error
            return
        }

        // get current index if no index is found we are on the last generation, so append then move
        var currentIndex = currentGenerationHistoryIndex
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
        error = textGenerationHistory[currentIndex - 1].error
    }

    var activeGenerationError: TextGenerationHistory? {
        guard error != .none else {
            return nil
        }

        if let currentIndex = currentGenerationHistoryIndex {
            let generation = textGenerationHistory[currentIndex]
            return generation.error == .none ? nil : generation
        }

        // Transient error on a generation that has not yet been stored to history
        // (e.g. a regeneration that errored before producing any text).
        return TextGenerationHistory(
            text: text,
            tokenCount: tokenCount,
            error: error
        )
    }

    /// Index of the history slot whose text + tokenCount match the current
    /// message. Error is intentionally excluded so that an errored slot remains
    /// locatable after its error is cleared/replaced (e.g. on retry).
    private var currentGenerationHistoryIndex: Int? {
        textGenerationHistory.lastIndex {
            $0.text == text
                && $0.tokenCount == tokenCount
        }
    }

    private var currentGenerationHistory: TextGenerationHistory {
        TextGenerationHistory(text: text, tokenCount: tokenCount, error: error)
    }

    /// Whether the current generation should be stored as a permanent history
    /// entry. Errored generations are never stored as history — they are
    /// transient state on the current slot and are replaced on retry.
    private var shouldStoreCurrentGeneration: Bool {
        text.isEmpty == false && error == .none
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
            let decodedHistory = try? JSONDecoder().decode(
                [TextGenerationHistory].self, from: jsonData)
        {
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
