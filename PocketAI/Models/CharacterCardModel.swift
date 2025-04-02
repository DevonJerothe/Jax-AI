//
//  CharacterCardModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/19/25.
//

import Foundation
import GRDB
import SwiftLLMSDK

struct CharacterCardModel {
    var id: UUID = UUID()
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

    init(fromChub: CharacterCard) {

    }
}

extension CharacterCardModel: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "char_cards"

    init(row: GRDB.Row) throws {
        id = UUID(uuidString: row["id"]!)!
        name = row["name"]
        description = row["description"]
        personality = row["personality"]
        firstMessage = row["firstMessage"]
        imagePath = row["imagePath"]
        messageExample = row["messageExample"]
        scenario = row["scenario"]
        systemPrompt = row["systemPrompt"]
        createdAt = row["createdAt"]

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
        container["description"] = description
        container["personality"] = personality
        container["firstMessage"] = firstMessage
        container["imagePath"] = imagePath
        container["messageExample"] = messageExample
        container["scenario"] = scenario
        container["systemPrompt"] = systemPrompt
        container["createdAt"] = createdAt

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
            t.column("id", .integer).primaryKey().notNull()
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
        }
    }
}
