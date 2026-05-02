import Foundation
import GRDB

struct UserPersonaModel {
    var id: UUID = UUID()
    var imageData: Data? 
    var name: String? 
    var description: String? 
    var active: Bool = false

    init(
        imageData: Data? = nil,
        name: String? = nil,
        description: String? = nil,
        active: Bool = false
    ) {
        self.imageData = imageData
        self.name = name
        self.description = description
        self.active = active
    }
}

extension UserPersonaModel {
    init(record: UserPersonaRecord) {
        self.id = UUID(uuidString: record.id) ?? UUID()
        self.imageData = record.imageData
        self.name = record.name
        self.description = record.description
        self.active = record.active
    }

    var record: UserPersonaRecord {
        UserPersonaRecord(
            id: id.uuidString,
            imageData: imageData,
            name: name, 
            description: description,
            active: active
        )
    }
}


struct UserPersonaRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "user_personas"

    var id: String
    var imageData: Data?
    var name: String? 
    var description: String? 
    var active: Bool = false

    public static func migrateTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column("id", .text).primaryKey().notNull()
            t.column("imageData", .blob)
            t.column("name", .text)
            t.column("description", .text)
            t.column("active", .boolean).defaults(to: false)
        }
    }
}