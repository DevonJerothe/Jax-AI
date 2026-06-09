import Foundation
import GRDB

class UserPersonaRepository: Repository {
    typealias T = UserPersonaModel

    private let db = DBManager.shared

    func getAll() throws -> [UserPersonaModel] {
        try db.read { db in
            try UserPersonaRecord.fetchAll(db).map { UserPersonaModel(record: $0) }
        }
    }

    func save(_ item: UserPersonaModel) throws {
        try db.write { db in 
            var record = item.record
            try record.save(db)
        }
    }

    func delete(_ item: UserPersonaModel) throws {
        try db.write { db in
            guard let record = try UserPersonaRecord.fetchOne(db, key: item.id.uuidString) else {
                return
            }
            try record.delete(db)
        }
    }
}