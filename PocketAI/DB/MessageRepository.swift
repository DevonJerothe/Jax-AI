class MessageRepository: Repository {
    typealias T = MessageModel

    private let dbManager = DBManager.shared

    func getAll() throws -> [MessageModel] {
        try dbManager.read { db in 
            try MessageModel.fetchAll(db)
        }
    }

    func save(_ item: MessageModel) throws {
        try dbManager.write { db in 
            try item.save(db)
        }
    }

    func delete(_ item: MessageModel) throws {
        _ = try dbManager.write { db in 
            try item.delete(db)
        }
    }
}