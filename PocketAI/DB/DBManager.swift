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

           // Create configuration for WAL mode
            var config = Configuration()
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode=WAL")
            }

            dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)

            try migrateTables()

            print("DB Opened Successfully with WAL mode enabled")
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
            try ChatCharacterJoin.migrateTable(db)
        }

        migrator.registerMigration("v2") { db in
            try db.alter(table: "messages") { t in
                t.add(column: "tokenCount", .integer).notNull().defaults(to: 0)
            }
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
