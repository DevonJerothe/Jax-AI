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

struct CharacterCardModel: Hashable {
    var id: UUID = UUID()
    var name: String?
    var description: String?
    var cardTagline: String? 
    var personality: String?
    var firstMessage: String?
    var imagePath: String?
    var messageExample: String?
    var scenario: String?
    var systemPrompt: String?
    var altGreetings: [String]?
    var tags: [String]?
    var createdAt: Date = Date()

    // IDs of chats that use this character card
    var chats: [String] = []

    var imageURL: URL?
    var imageData: Data?
    
    init(
        name: String? = nil,
        description: String? = nil,
        cardTagline: String? = nil,
        personality: String? = nil,
        firstMessage: String? = nil,
        messageExample: String? = nil,
        scenario: String? = nil,
        systemPrompt: String? = nil,
        altGreetings: [String] = [],
        tags: [String] = [],
        imageData: Data? = nil,
        chats: [String] = []
    ) {
        self.name = name
        self.description = description
        self.cardTagline = cardTagline
        self.personality = personality
        self.firstMessage = firstMessage
        self.messageExample = messageExample
        self.scenario = scenario
        self.systemPrompt = systemPrompt
        self.altGreetings = altGreetings
        self.tags = tags
        self.imageData = imageData
        self.chats = chats
    }

    init(fromChub: CharacterCard) {
        let chubData = fromChub.data
        self.name = chubData?.name
        self.description = chubData?.description
        self.cardTagline = fromChub.cardDescription
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

    // MARK: - Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(cardTagline)
        hasher.combine(personality)
        hasher.combine(firstMessage)
        hasher.combine(imagePath)
        hasher.combine(messageExample)
        hasher.combine(scenario)
        hasher.combine(systemPrompt)
        hasher.combine(altGreetings)
        hasher.combine(tags)
        hasher.combine(createdAt)
        hasher.combine(chats)
        hasher.combine(imageData)
    }
    
    static func == (lhs: CharacterCardModel, rhs: CharacterCardModel) -> Bool {
        // Break up the long comparison into multiple lines for better readability and performance
        guard lhs.id == rhs.id,
            lhs.name == rhs.name,
            lhs.description == rhs.description,
            lhs.cardTagline == rhs.cardTagline,
            lhs.personality == rhs.personality,
            lhs.firstMessage == rhs.firstMessage,
            lhs.imagePath == rhs.imagePath,
            lhs.messageExample == rhs.messageExample,
            lhs.scenario == rhs.scenario,
            lhs.systemPrompt == rhs.systemPrompt,
            lhs.altGreetings == rhs.altGreetings,
            lhs.tags == rhs.tags,
            lhs.createdAt == rhs.createdAt,
            lhs.chats == rhs.chats,
            lhs.imageData == rhs.imageData else 
        {
            return false
        }
        return true
    }

    // MARK: - Helping functions
    func getAvatarImg() -> Image? {
        if let imgData = imageData, let uiImage = UIImage(data: imgData) {
            return Image(uiImage: uiImage)
        }
        return nil
    }
}

extension CharacterCardModel: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "char_cards"

    init(row: GRDB.Row) throws {
        id = UUID(uuidString: row["id"]!)!
        name = row["name"]
        description = row["description"]
        cardTagline = row["cardTagline"]
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
        container["name"] = name
        container["description"] = description
        container["cardTagline"] = cardTagline
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
            t.column("name", .text)
            t.column("description", .text)
            t.column("cardTagline", .text)
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

