import GRDB
import Foundation

class ChatRepository: Repository {
    typealias T = ChatModel

    private let dbManager = DBManager.shared

    func getAll() throws -> [ChatModel] {
        try dbManager.read { db in 
            var chats = try ChatModel.fetchAll(db).sorted { $0.updatedAt > $1.updatedAt }

            for i in 0..<chats.count {
                let chatId = chats[i].id.uuidString
                
                // Fetch messages for this chat
                let messages = try MessageModel.filter(Column("chatId") == chatId).order(Column("createdAt").asc).fetchAll(db)
                chats[i].messages = messages
                
                // Fetch associated character cards using the join table
                let characterCardIds = try ChatCharacterJoin
                    .filter(Column("chatId") == chatId)
                    .fetchAll(db)
                    .map { $0.characterCardId }
                
                // Fetch the actual character card models
                var characterCards: [CharacterCardModel] = []
                for cardId in characterCardIds {
                    if let card = try CharacterCardModel.filter(Column("id") == cardId).fetchOne(db) {
                        characterCards.append(card)
                    }
                }
                chats[i].characterCard = characterCards
            }

            return chats
        }
    }

    func save(_ item: ChatModel) throws {
        try dbManager.write { db in
            var mutableItem = item
            mutableItem.updatedAt = Date()
            try mutableItem.save(db)
            
            // Save the character card - prob dont need to do this but better to be safe... I'll worry bout performance later.
            for charModel in mutableItem.characterCard {
                try charModel.save(db)
            }
            
            let associatedCharIds = try ChatCharacterJoin
                .filter(Column("chatId") == mutableItem.id.uuidString)
                .fetchAll(db)
                .map { $0.characterCardId }
            
            let attachedCharacters = mutableItem.characterCard.map { $0.id.uuidString }
            
            // Remove / add joins
            let removeIds = Set(associatedCharIds).subtracting(Set(attachedCharacters))
            let addIds = Set(attachedCharacters).subtracting(Set(associatedCharIds))
            
            if removeIds.isEmpty == false {
                try ChatCharacterJoin
                    .filter(Column("chatId") == mutableItem.id.uuidString)
                    .filter(removeIds.contains(Column("charCardId")))
                    .deleteAll(db)
            }
            
            for characterId in addIds {
                let association = ChatCharacterJoin(chatId: mutableItem.id.uuidString, characterCardId: characterId)
                try association.save(db)
            }
            
            // Save all messages
            try MessageModel.filter(Column("chatId") == mutableItem.id.uuidString).deleteAll(db)
            for (index, var message) in mutableItem.messages.enumerated() {
                message.chatId = mutableItem.id.uuidString
                print("Saving message \(index+1)/\(mutableItem.messages.count): \(message.id.uuidString)")
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
