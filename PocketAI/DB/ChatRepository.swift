import GRDB

class ChatRepository: Repository {
    typealias T = ChatModel

    private let dbManager = DBManager.shared

    func getAll() throws -> [ChatModel] {
        try dbManager.read { db in 
            var chats = try ChatModel.fetchAll(db) 

            for i in 0..<chats.count {
                let chatId = chats[i].id.uuidString
                let messages = try MessageModel.filter(Column("chatId") == chatId).order(Column("createdAt").asc).fetchAll(db)
                chats[i].messages = messages
                
                // Fetch the associated character card there should always be one.. if not something is broken.
                let charCard = try CharacterCardModel.filter(Column("chatId") == chatId).limit(1).fetchOne(db)!
                chats[i].characterCard = charCard
            }

            return chats
        }
    }

    func save(_ item: ChatModel) throws {
        try dbManager.write { db in
            try item.save(db)
            
            // Save the character card - prob dont need to do this but better to be safe... I'll worry bout performance later.
            try item.characterCard.save(db)
            
            // Save all messages
            try MessageModel.filter(Column("chatId") == item.id.uuidString).deleteAll(db)
            for (index, var message) in item.messages.enumerated() {
                message.chatId = item.id.uuidString
                print("Saving message \(index+1)/\(item.messages.count): \(message.id.uuidString)")
                try message.save(db)
            }
        }
    }

    func delete(_ item: ChatModel) throws {
        _ = try dbManager.write { db in 
            try item.delete(db)
        }
    }
}
