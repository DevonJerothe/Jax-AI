//
//  CharacterCardModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/19/25.
//

import Foundation
import GRDB
import SwiftLLMSDK
import SwiftUI

struct CharacterCardModel {
    var id: UUID = UUID()
    var chatId: String = ""
    var name: String?
    var description: String?
    var personality: String?
    var firstMessage: String?
    var imagePath: String?
    var messageExample: String?
    var scenario: String?
    var systemPrompt: String?
    var altGreetings: [String]?
    var tags: [String]?
    var createdAt: Date = Date()

    var imageURL: URL?
    var imageData: Data?
    
    init(
        chatId: String = "",
        name: String,
        description: String? = nil,
        personality: String? = nil,
        firstMessage: String? = nil,
        messageExample: String? = nil,
        scenario: String? = nil,
        systemPrompt: String? = nil,
        altGreetings: [String] = [],
        tags: [String] = [],
        imageData: Data? = nil
    ) {
        self.chatId = chatId
        self.name = name
        self.description = description
        self.personality = personality
        self.firstMessage = firstMessage
        self.messageExample = messageExample
        self.scenario = scenario
        self.systemPrompt = systemPrompt
        self.altGreetings = altGreetings
        self.tags = tags
        self.imageData = imageData
    }

    init(fromChub: CharacterCard) {
        let chubData = fromChub.data
        self.name = chubData?.name
        self.description = chubData?.description
        self.personality = chubData?.personality
        self.firstMessage = chubData?.firstMessage
        self.imagePath = chubData?.avatar
        self.messageExample = chubData?.messageExamples
        self.scenario = chubData?.scenario
        self.systemPrompt = chubData?.systemPrompt
        self.altGreetings = chubData?.alternateGreetings
        self.tags = chubData?.tags
        
        if let imagePath = imagePath, imagePath.isEmpty == false {
            self.imageURL = URL(string: imagePath)
        }
        
        // There should always be a png file if importing from chub
        self.imageData = fromChub.pngData
    }
}

extension CharacterCardModel: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "char_cards"

    init(row: GRDB.Row) throws {
        id = UUID(uuidString: row["id"]!)!
        chatId = row["chatId"]
        name = row["name"]
        description = row["description"]
        personality = row["personality"]
        firstMessage = row["firstMessage"]
        imagePath = row["imagePath"]
        messageExample = row["messageExample"]
        scenario = row["scenario"]
        systemPrompt = row["systemPrompt"]
        createdAt = row["createdAt"]
        imageData = row["imageData"]

        if let urlString = row["imagePath"] as? String {
            imageURL = URL(string: urlString)
        }

        // Decode JSON strings to arrays
        if let altGreetingsString = row["altGreetings"] as? String,
           let altGreetingsData = altGreetingsString.data(using: .utf8) {
            altGreetings = try JSONDecoder().decode([String].self, from: altGreetingsData)
        }
        
        if let tagsString = row["tags"] as? String,
           let tagsData = tagsString.data(using: .utf8) {
            tags = try JSONDecoder().decode([String].self, from: tagsData)
        }
    }

    func encode(to container: inout GRDB.PersistenceContainer) throws {
        container["id"] = id.uuidString
        container["chatId"] = chatId
        container["name"] = name
        container["description"] = description
        container["personality"] = personality
        container["firstMessage"] = firstMessage
        container["imagePath"] = imagePath
        container["messageExample"] = messageExample
        container["scenario"] = scenario
        container["systemPrompt"] = systemPrompt
        container["createdAt"] = createdAt
        container["imageData"] = imageData

        // Encode arrays to JSON strings
        if let altGreetings = altGreetings {
            let altGreetingsData = try JSONEncoder().encode(altGreetings)
            container["altGreetings"] = String(data: altGreetingsData, encoding: .utf8)
        }
        
        if let tags = tags {
            let tagsData = try JSONEncoder().encode(tags)
            container["tags"] = String(data: tagsData, encoding: .utf8)
        }
    }
}
extension CharacterCardModel {
    public static func migrateTable(_ db: Database) throws {
        try db.create(table: "char_cards", ifNotExists: true) { t in
            t.column("id", .text).primaryKey().notNull()
            t.column("chatId", .text).notNull().indexed().references("chats", onDelete: .cascade)
            t.column("name", .text)
            t.column("description", .text)
            t.column("personality", .text)
            t.column("firstMessage", .text)
            t.column("imagePath", .text)
            t.column("messageExample", .text)
            t.column("scenario", .text)
            t.column("systemPrompt", .text)
            t.column("altGreetings", .text)
            t.column("tags", .text)
            t.column("createdAt", .datetime).notNull().defaults(to: "CURRENT_TIMESTAMP")
            t.column("imageData", .blob)
        }
    }
}

