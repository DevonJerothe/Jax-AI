//
//  DBManager.swift
//  PocketAI
//
//  Created by devon jerothe on 3/15/25.
//

import Foundation
import GRDB 

protocol Repository {
    associatedtype T

    func getAll() throws -> [T]
    // func get(id: String) throws -> T?
    func save(_ item: T) throws 
    func delete(_ item: T) throws
}

class DBManager {
    static let shared = DBManager() 

    private var dbQueue: DatabaseQueue!
    private var migrator: DatabaseMigrator = DatabaseMigrator()

    private init() {
        setup()
    }

    private func setup() {
        do {
            let dbURL = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("pocketai.sqlite")
            
            print("Database path: \(dbURL.path)")
            
            // Check if directory exists
            let directoryURL = dbURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                print("Created directory at: \(directoryURL.path)")
            }

            dbQueue = try DatabaseQueue(path: dbURL.path) 

            try migrateTables()

            print("DB Opened Successfully")
        } catch {
            print("Database setup error: \(error)")
            fatalError("Failed to setup database: \(error)")
        }
    }

    private func migrateTables() throws {

        migrator.registerMigration("v1") { db in
            try ChatModel.migrateTable(db)
            try MessageModel.migrateTable(db)
            try CharacterCardModel.migrateTable(db)
        }

        try migrator.migrate(dbQueue)
    }

    func write<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.write(block)
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
