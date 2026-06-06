//
//  DBManager.swift
//  PocketAI
//
//  Created by devon jerothe on 3/15/25.
//

import Foundation
import GRDB

enum AppDBError: LocalizedError {
    case unavailable
    case startupFailed(String)
    case recordNotFound(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Database is unavailable."
        case .startupFailed(let message):
            "Database startup failed: \(message)"
        case .recordNotFound(let record):
            "Record not found: \(record)"
        }
    }
}

protocol Repository {
    associatedtype T

    func getAll() throws -> [T]
    // func get(id: String) throws -> T?
    func save(_ item: T) throws
    func delete(_ item: T) throws
}

class DBManager {
    static let shared = DBManager()

    var dbQueue: DatabaseQueue?
    private var migrator: DatabaseMigrator = DatabaseMigrator()
    var startUpError: AppDBError?

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
            startUpError = .startupFailed(error.localizedDescription)
        }
    }

    private func migrateTables() throws {
        guard let dbQueue else {
            throw startUpError ?? .unavailable
        }

        migrator.registerMigration("v1") { db in
            try ChatRecord.migrateTable(db)
            try CharacterCardRecord.migrateTable(db)
            try MessageRecord.migrateTable(db)
            try ChatCharacterJoinRecord.migrateTable(db)
        }

        migrator.registerMigration("v2_privacy_flags") { db in
            let chatColumns = try db.columns(in: ChatRecord.databaseTableName).map(\.name)
            if chatColumns.contains("isPrivate") == false {
                try db.alter(table: ChatRecord.databaseTableName) { t in
                    t.add(column: "isPrivate", .boolean).notNull().defaults(to: false)
                }
            }

            let characterColumns = try db.columns(in: CharacterCardRecord.databaseTableName).map(
                \.name)
            if characterColumns.contains("isPrivate") == false {
                try db.alter(table: CharacterCardRecord.databaseTableName) { t in
                    t.add(column: "isPrivate", .boolean).notNull().defaults(to: false)
                }
            }
        }

        migrator.registerMigration("v3_user_persona") { db in
            try UserPersonaRecord.migrateTable(db)
        }

        migrator.registerMigration("v4_message_token_count") { db in
            let messageColumns = try db.columns(in: MessageRecord.databaseTableName).map(\.name)
            if messageColumns.contains("tokenCountModel") == false {
                try db.alter(table: MessageRecord.databaseTableName) { t in
                    t.add(column: "tokenCountModel", .text)
                }
            }
        }

        migrator.registerMigration("v5_message_text_generation_history") { db in
            let messageColumns = try db.columns(in: MessageRecord.databaseTableName).map(\.name)
            if messageColumns.contains("textGenerationHistoryJSON") == false {
                try db.alter(table: MessageRecord.databaseTableName) { t in
                    t.add(column: "textGenerationHistoryJSON", .text)
                }
            }
        }

        migrator.registerMigration("v6_lore_books") { db in
            try LoreBookRecord.migrateTable(db)
            try LoreBookEntryRecord.migrateTable(db)
            try ChatLoreBookJoinRecord.migrateTable(db)
        }

        migrator.registerMigration("v7_lore_book_description") { db in
            let loreBookColumns = try db.columns(in: LoreBookRecord.databaseTableName).map(\.name)
            if loreBookColumns.contains("description") == false {
                try db.alter(table: LoreBookRecord.databaseTableName) { t in
                    t.add(column: "description", .text)
                }
            }
        }
        try migrator.migrate(dbQueue)
    }

    func write<T>(_ block: (Database) throws -> T) throws -> T {
        guard let dbQueue else {
            throw startUpError ?? .unavailable
        }
        return try dbQueue.write(block)
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        guard let dbQueue else {
            throw startUpError ?? .unavailable
        }
        return try dbQueue.read(block)
    }
}
