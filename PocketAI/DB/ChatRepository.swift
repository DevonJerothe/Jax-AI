import GRDB
import Foundation

class ChatRepository: Repository {
    typealias T = ChatModel

    private let dbManager = DBManager.shared
    
    /// Auto listen for any DB changes for chars / chats / and messages. Call from a store or shared location where a single
    /// in memory array can be source of truth.
    ///
    /// TODO: returning all messages on all chats can become expensive here. We should limit it to one so we have the
    /// lat message in our cell view, then observe the messages seperatly once in the chat view.
    func observeAll() throws -> some AsyncSequence<[ChatModel], Error> {
        guard let writer = dbManager.dbQueue else {
            throw AppDBError.unavailable
        }
        
        let observer = ValueObservation.tracking { db in
            let chatsRequest = ChatRecord
                .including(all: ChatRecord.characterCards)
                .including(all: ChatRecord.messages.order(Column("createdAt").asc))
                .order(Column("updatedAt").desc)
                .asRequest(of: ChatWithCharacterCards.self)
            
            let chatsWithCharacters = try chatsRequest.fetchAll(db)
            
            let chats = chatsWithCharacters.map { model in
                var chat = ChatModel(record: model.chat)
                chat.characterCards = model.characterCards.map { CharacterCardModel(record: $0) }
                chat.messages = model.messages.map { MessageModel(record: $0) }
                return chat
            }
            
            return chats
        }
        return observer.values(in: writer)
        
    }
    
    func getAll() throws -> [ChatModel] {
        try dbManager.read { db in
            let chatsRequest = ChatRecord
                .including(all: ChatRecord.characterCards)
                .including(all: ChatRecord.messages.order(Column("createdAt").asc))
                .order(Column("updatedAt").desc)
                .asRequest(of: ChatWithCharacterCards.self)

            // fetch DTO
            let chatsWithCharacters = try chatsRequest.fetchAll(db)
            
            let chats = chatsWithCharacters.map { model in
                var chat = ChatModel(record: model.chat)
                chat.characterCards = model.characterCards.map { CharacterCardModel(record: $0) }
                chat.messages = model.messages.map { MessageModel(record: $0) }
                return chat
            }

            return chats
        }
    }
    
    func save(_ item: ChatModel) throws {
        try dbManager.write { db in
            var record = item.record
            record.isPrivate = item.isPrivate || item.characterCards.contains(where: \.isPrivate)
            record.updatedAt = Date()
            try record.save(db)

            // save character cards
            for characterCard in item.characterCards {
                var record = characterCard.record
                try record.save(db)
            }

            // save chat character joins
            let attachedCharacters = item.characterCards.map { $0.id.uuidString }

            // clean up stale join records
            let associatedJoinRecords = try ChatCharacterJoinRecord.filter(Column("chatId") == item.id.uuidString).fetchAll(db).map { $0.characterCardId }
            let staleRecords = Set(associatedJoinRecords).subtracting(attachedCharacters)
            let newRecords = Set(attachedCharacters).subtracting(associatedJoinRecords)

            // delete stale join records
            if staleRecords.isEmpty == false {
                try ChatCharacterJoinRecord.filter(Column("chatId") == item.id.uuidString).filter(staleRecords.contains(Column("characterCardId"))).deleteAll(db)
            }

            // save new join records
            for characterCardId in newRecords {
                var record = ChatCharacterJoinRecord(chatId: item.id.uuidString, characterCardId: characterCardId)
                try record.save(db)
            }
        }
    }
    
    func delete(_ item: ChatModel) throws {
        try dbManager.write { db in
            guard let record = try ChatRecord.fetchOne(db, key: item.id.uuidString) else {
                return
            }

            try record.delete(db)
        }
    }
}
