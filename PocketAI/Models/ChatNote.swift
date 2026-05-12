import Foundation 
import SwiftUI 

struct ChatNoteModel: Codable, Hashable {
    var id: UUID = UUID() 
    var note: String 
    var depth: Int
    var injectInMemory: Bool
    var updatedAt: Date = Date() 
    var createdAt: Date = Date() 

    init(
        note: String,
        depth: Int,
        injectInMemory: Bool, 
        updatedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.note = note
        self.depth = depth
        self.injectInMemory = injectInMemory
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }
}

extension ChatNoteModel {
    var contentIdentifier: String {
        return "\(id.uuidString)-\(note)-\(depth)-\(injectInMemory)"
    }
}

extension ChatNoteModel {
    var toJSON: String? {
        guard let json = try? JSONEncoder().encode(self) else { return nil }
        return String(data: json, encoding: .utf8) ?? ""
    }

    static func fromJSON(json: String) -> ChatNoteModel? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ChatNoteModel.self, from: data)
    }
}