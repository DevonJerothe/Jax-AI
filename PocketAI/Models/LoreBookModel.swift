import Foundation
import GRDB

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

    init(
        id: UUID = UUID(),
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
