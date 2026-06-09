import Foundation
import GRDB
import SwiftLLMSDK

struct LoreBookModel: Hashable, Identifiable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var name: String
    var description: String?
    var scanDepth: Int
    var tokenBudget: Int?
    var recursiveScanning: Bool
    var isPrivate: Bool = false
    var entries: [LoreBookEntryModel] = []
    var chats: [ChatModel] = []

    var characterCardId: String? 

    init(
        id: UUID = UUID(),
        characterCardId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        name: String,
        description: String? = nil,
        scanDepth: Int,
        tokenBudget: Int? = nil,
        recursiveScanning: Bool = false,
        isPrivate: Bool = false,
        entries: [LoreBookEntryModel] = [],
        chats: [ChatModel] = []
    ) {
        self.id = id
        self.characterCardId = characterCardId?.uuidString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.description = description
        self.scanDepth = scanDepth
        self.tokenBudget = tokenBudget
        self.recursiveScanning = recursiveScanning
        self.isPrivate = isPrivate
        self.entries = entries
        self.chats = chats
    }

    init(fromImport: LoreBook, forCharacter: UUID? = nil) {
        let entries = fromImport.entries ?? [:]
        let loreBookID = UUID()

        self.characterCardId = forCharacter?.uuidString
        self.id = loreBookID
        self.createdAt = Date() 
        self.updatedAt = Date()
        self.name = fromImport.name ?? "Imported LoreBook"
        self.description = fromImport.description
        self.scanDepth = fromImport.scanDepth ?? 2 
        self.tokenBudget = fromImport.tokenBudget
        self.recursiveScanning = fromImport.recursiveScanning ?? false

        self.entries = entries.enumerated().map { index, pair in 
            LoreBookEntryModel(
                loreBookId: loreBookID.uuidString,
                name: pair.value.name ?? pair.value.comment ?? "Entry \(index + 1)", 
                enabled: pair.value.enabled ?? !(pair.value.disable ?? false),
                keys: pair.value.keys ?? pair.value.key ?? [],
                secondaryKeys: pair.value.secondaryKeys ?? pair.value.keysecondary ?? [],
                content: pair.value.content ?? "", 
                constant: pair.value.constant ?? false, 
                order: pair.value.order ?? 1, 
                position: pair.value.position?.intValue ?? 2,
                caseSensitive: pair.value.caseSensitive ?? false, 
                depth: pair.value.depth ?? pair.value.extensions?.depth ?? 2
            )
        }
    }
}

struct LoreBookEntryModel: Hashable, Identifiable {
    var id: UUID = UUID()
    var loreBookId: String = ""
    var name: String
    var enabled: Bool?
    var keys: [String]
    var secondaryKeys: [String]
    var content: String
    var constant: Bool?
    var order: Int?
    var position: Int?
    var caseSensitive: Bool?
    var depth: Int?

    init(
        id: UUID = UUID(),
        loreBookId: String = "",
        name: String,
        enabled: Bool?,
        keys: [String],
        secondaryKeys: [String],
        content: String,
        constant: Bool?,
        order: Int?,
        position: Int?,
        caseSensitive: Bool?,
        depth: Int?
    ) {
        self.id = id
        self.loreBookId = loreBookId
        self.name = name
        self.enabled = enabled
        self.keys = keys
        self.secondaryKeys = secondaryKeys
        self.content = content
        self.constant = constant
        self.order = order
        self.position = position
        self.caseSensitive = caseSensitive
        self.depth = depth
    }
}

extension LoreBookModel {
    init(record: LoreBookRecord) {
        self.id = UUID(uuidString: record.id) ?? UUID()
        self.characterCardId = record.characterCardId
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
        self.name = record.name
        self.description = record.description
        self.scanDepth = record.scanDepth
        self.tokenBudget = record.tokenBudget
        self.recursiveScanning = record.recursiveScanning
        self.isPrivate = record.isPrivate
        self.entries = []
        self.chats = []
    }

    var record: LoreBookRecord {
        LoreBookRecord(
            id: id.uuidString,
            characterCardId: characterCardId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            name: name,
            description: description,
            scanDepth: scanDepth,
            tokenBudget: tokenBudget,
            recursiveScanning: recursiveScanning,
            isPrivate: isPrivate
        )
    }
}

extension LoreBookEntryModel {
    init(record: LoreBookEntryRecord) {
        self.id = UUID(uuidString: record.id) ?? UUID()
        self.loreBookId = record.loreBookId
        self.name = record.name
        self.enabled = record.enabled
        self.keys = (try? record.keys.decodeStringArray()) ?? []
        self.secondaryKeys = (try? record.secondaryKeys?.decodeStringArray()) ?? []
        self.content = record.content
        self.constant = record.constant
        self.order = record.order
        self.position = record.position
        self.caseSensitive = record.caseSensitive
        self.depth = record.depth
    }

    var record: LoreBookEntryRecord {
        LoreBookEntryRecord(
            id: id.uuidString,
            loreBookId: loreBookId,
            name: name,
            enabled: enabled,
            keys: keys.encodeStringArray(),
            secondaryKeys: secondaryKeys.encodeStringArray(),
            content: content,
            constant: constant,
            order: order,
            position: position,
            caseSensitive: caseSensitive,
            depth: depth
        )
    }
}

struct LoreBookRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "lorebooks"

    static let entries = hasMany(LoreBookEntryRecord.self, using: ForeignKey([Column("loreBookId")]))
    static let chatLoreBookJoins = hasMany(ChatLoreBookJoinRecord.self, using: ForeignKey([Column("loreBookId")]))
    static let chats = hasMany(
        ChatRecord.self,
        through: chatLoreBookJoins,
        using: ChatLoreBookJoinRecord.chat
    )

    var id: String
    var characterCardId: String?
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var description: String?
    var scanDepth: Int
    var tokenBudget: Int?
    var recursiveScanning: Bool
    var isPrivate: Bool = false

    public static func migrateTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { builder in
            builder.column("id", .text).primaryKey().notNull()
            builder.column("characterCardId", .text).unique().references(CharacterCardRecord.databaseTableName, onDelete: .setNull)
            builder.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            builder.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            builder.column("name", .text).notNull()
            builder.column("description", .text)
            builder.column("scanDepth", .integer).notNull().defaults(to: 2)
            builder.column("tokenBudget", .integer)
            builder.column("recursiveScanning", .boolean).notNull().defaults(to: false)
            builder.column("isPrivate", .boolean).notNull().defaults(to: false)
        }
    }
}

struct LoreBookEntryRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "lorebook_entries"

    static let loreBook = belongsTo(LoreBookRecord.self, using: ForeignKey([Column("loreBookId")]))

    var id: String
    var loreBookId: String
    var name: String
    var enabled: Bool?
    var keys: String
    var secondaryKeys: String?
    var content: String
    var constant: Bool?
    var order: Int?
    var position: Int?
    var caseSensitive: Bool?
    var depth: Int?

    public static func migrateTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { builder in
            builder.column("id", .text).primaryKey().notNull()
            builder.column("loreBookId", .text).notNull().indexed().references(
                LoreBookRecord.databaseTableName, onDelete: .cascade)
            builder.column("name", .text).notNull()
            builder.column("enabled", .boolean).notNull().defaults(to: true)
            builder.column("keys", .text).notNull()
            builder.column("secondaryKeys", .text)
            builder.column("content", .text).notNull()
            builder.column("constant", .boolean).notNull().defaults(to: false)
            builder.column("order", .integer).notNull().defaults(to: 0)
            builder.column("position", .integer).notNull().defaults(to: 0)
            builder.column("caseSensitive", .boolean).notNull().defaults(to: false)
            builder.column("depth", .integer).notNull().defaults(to: 0)
        }
    }
}

struct LoreBookWithEntriesAndChats: Decodable, FetchableRecord {
    let loreBook: LoreBookRecord
    let entries: [LoreBookEntryRecord]
    let chats: [ChatRecord]
}

enum LoreBookEntryPosition: Int {
    case beforeChar = 0
    case afterChar = 1
    case atDepth = 2

    init(rawValue: Int?) {
        self = LoreBookEntryPosition(rawValue: rawValue ?? 2) ?? .atDepth
    }
}