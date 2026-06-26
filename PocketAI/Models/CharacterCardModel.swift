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
import SwiftTiktoken

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
    var isPrivate: Bool = false

    // This can be used to hide the character from UI. This should be used for quick chat instances, and "no character" based chats
    var isSystemChar: Bool = false 

    var chats: [ChatModel] = []
    var characterBook: LoreBookModel?
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
        chats: [ChatModel] = [],
        characterBook: LoreBookModel? = nil,
        isSystemChar: Bool = false
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
        self.characterBook = characterBook
        self.isSystemChar = isSystemChar
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

        if let characterBook = chubData?.characterBook {
            self.characterBook = LoreBookModel(fromImport: characterBook)
        }
    }

    // MARK: - Helping functions
    func getAvatarImg() -> Image? {
        if let imgData = imageData, let uiImage = UIImage(data: imgData) {
            return Image(uiImage: uiImage)
        }
        return nil
    }

    // Baseline estimate for UI cards. This will only count the initial message. 
    // We should still pull an accurate token count from `/tokenCount` if running KoboldCPP
    func tokenCount() async -> Int {
        let tokenizer = try? await CoreBPE.cl100kBase() // standard 100k tokenizer. May need to bump to 200k or give a safe buffer. 
        guard let tokenizer = tokenizer else { return 0 }
        
        var characterCardText = "" 
        if let description = description {
            characterCardText = description
        }
        if let cardTagline = cardTagline {
            characterCardText += "\n" + cardTagline
        }
        if let personality = personality {
            characterCardText += "\n" + personality
        }
        if let firstMessage = firstMessage {
            characterCardText += "\n" + firstMessage
        }
        if let messageExample = messageExample {
            characterCardText += "\n" + messageExample
        }
        if let scenario = scenario {
            characterCardText += "\n" + scenario
        }

        let tokens = tokenizer.encodeWithSpecialTokens(text: characterCardText)
        return tokens.count
    }
}

extension CharacterCardModel {
    init(record: CharacterCardRecord) {
        self.id = UUID(uuidString: record.id) ?? UUID() 
        self.name = record.name
        self.description = record.description
        self.cardTagline = record.cardTagline
        self.personality = record.personality
        self.firstMessage = record.firstMessage
        self.imagePath = record.imagePath
        self.messageExample = record.messageExample
        self.scenario = record.scenario
        self.systemPrompt = record.systemPrompt
        self.createdAt = record.createdAt
        self.imageData = record.imageData
        self.isPrivate = record.isPrivate
        self.isSystemChar = record.isSystemChar

        self.altGreetings = try? record.altGreetings?.decodeStringArray() ?? []
        self.tags = try? record.tags?.decodeStringArray() ?? []

        self.chats = []
        self.characterBook = nil
        self.imageURL = record.imagePath.flatMap(URL.init(string:))
    }

    var record: CharacterCardRecord {
        CharacterCardRecord(
            id: id.uuidString,
            name: name,
            description: description,
            cardTagline: cardTagline,
            personality: personality,
            firstMessage: firstMessage,
            imagePath: imagePath,
            messageExample: messageExample,
            scenario: scenario,
            systemPrompt: systemPrompt,
            altGreetings: altGreetings?.encodeStringArray() ?? "",
            tags: tags?.encodeStringArray() ?? "",
            createdAt: createdAt,
            imageData: imageData,
            isPrivate: isPrivate,
            isSystemChar: isSystemChar
        )
    }

    static func systemCard() -> CharacterCardModel {
        return CharacterCardModel(
            name: "Jax AI", 
            description: CardTemplates().quickChat,
            personality: CardTemplates().quickChatPersonality, 
            isSystemChar: true
        )
    }
}

struct CharacterCardRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "char_cards"
    static let chatCharacterJoins = hasMany(ChatCharacterJoinRecord.self, using: ForeignKey([Column("characterCardId")]))
    static let chats = hasMany(
        ChatRecord.self, 
        through: chatCharacterJoins, 
        using: ChatCharacterJoinRecord.chat
    ) 
    static let characterBook = hasOne(
        LoreBookRecord.self, 
        using: ForeignKey([Column("characterCardId")])
    ).forKey("characterBook")

    var id: String 
    var name: String?
    var description: String?
    var cardTagline: String?
    var personality: String?
    var firstMessage: String?
    var imagePath: String?
    var messageExample: String?
    var scenario: String?
    var systemPrompt: String?
    var altGreetings: String? 
    var tags: String? 
    var createdAt: Date 
    var imageData: Data? 
    var isPrivate: Bool = false
    var isSystemChar: Bool = false
    
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
            t.column("isPrivate", .boolean).notNull().defaults(to: false)
            t.column("isSystemChar", .boolean).notNull().defaults(to: false)
        }
    }
}

struct CharacterCardWithChats: Decodable, FetchableRecord {
    let characterCard: CharacterCardRecord
    let chats: [ChatRecord]
    let characterBook: LoreBookRecord?
}
