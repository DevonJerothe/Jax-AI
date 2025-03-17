//
//  DBManager.swift
//  PocketAI
//
//  Created by devon jerothe on 3/15/25.
//

import Foundation
import GRDB 

class DBManager {
    static let shared = DBManager() 

    private var dbQueue: DatabaseQueue!

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
        try dbQueue.write { db in 
            try db.create(table: "chats", ifNotExists: true) { t in 
                t.column("id", .text).primaryKey().notNull()
                t.column("chatTitle", .text).notNull()
                t.column("memory", .text).notNull()
                t.column("firstMessage", .text).notNull()
            }

            try db.create(table: "messages", ifNotExists: true) { t in 
                t.column("id", .text).primaryKey().notNull()
                t.column("chatId", .text).notNull().indexed().references("chats", onDelete: .cascade)
                t.column("actor", .integer).notNull()
                t.column("text", .text).notNull()
                t.column("loading", .boolean).notNull()
                t.column("exclude", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
        }
    }

    func write<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.write(block)
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
