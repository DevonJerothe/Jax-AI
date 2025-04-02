//
//  CharacterCard.swift
//  SwiftLLMSDK
//
//  Created by devon jerothe on 3/18/25.
//


import Foundation


// Add ID for DB support. NOTE: This should be done via the application. 
public class CharacterCard: Codable {
    public var id: UUID = UUID()
    public var spec: String?
    public var spec_version: String?
    public var data: CharacterCardData?
}

public class CharacterCardData: Codable {
    public var id: UUID = UUID()
    public var name: String?
    public var description: String?
    public var personality: String?
    public var firstMessage: String? // first_mes
    public var avatar: String?
    public var messageExamples: String? // mes_example
    public var scenario: String?
    public var creatorNotes: String?
    public var systemPrompt: String?
    public var postHistoryInstructions: String?
    public var creator: String?
    public var characterVersion: String?
    public var alternateGreetings: [String]?
    public var tags: [String]?

    public enum CodingKeys: String, CodingKey {
        case messageExamples = "mes_example"
        case firstMessage = "first_mes"
        case name = "name"
        case description = "description"
        case personality = "personality"
        case avatar = "avatar"
        case scenario = "scenario"
        case creatorNotes = "creator_notes"
        case systemPrompt = "system_prompt"
        case postHistoryInstructions = "post_history_instructions"
        case creator = "creator"
        case characterVersion = "character_version"
        case alternateGreetings = "alternate_greetings"
        case tags = "tags"
    }

    // TODO: add support for the following
//    public var extenstions:
//    public var character_book:
}
