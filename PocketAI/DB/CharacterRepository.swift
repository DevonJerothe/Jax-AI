//
//  CharacterRepository.swift
//  PocketAI
//
//  Created by devon jerothe on 3/19/25.
//

import Foundation
import GRDB
import SwiftLLMSDK

class CharacterRepository: Repository {
    typealias T = CharacterCardModel

    private let dbManager = DBManager.shared

    func getAll() throws -> [CharacterCardModel] {
        try dbManager.read { db in 
            return try CharacterCardModel.fetchAll(db)
        }
    }

    func save(_ item: CharacterCardModel) throws {
        _ = try dbManager.write { db in 
            try item.save(db)
        }
    }

    func delete(_ item: CharacterCardModel) throws {
        _ = try dbManager.write { db in 
            try item.delete(db)
        }
    }
}
