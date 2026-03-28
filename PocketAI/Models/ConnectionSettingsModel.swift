//
//  ConnectionSettingsModel.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//

import Collections

enum APITypeSelection: String, Codable {
    case KoboldAPI
    case OpenRouter
}

public struct TemplateModel: Codable, Equatable {
    var content: String
    var isEnabled: Bool
}

public struct ConnectionSettingsModel: Codable {
    var host: String?
    var port: Int?
    var connectionType: APITypeSelection = .KoboldAPI
    var contextLength: Int?
    var maxContextLength: Int? // KoboldAPI only
    var responseLength: Int?
    var apiKey: String?
    var selectedModel: String?

    // Sampler Settings 
    var temperature: Double?
    var topP: Double?
    var topK: Int?
    var typicalP: Double?
    var repetitionPenalty: Double?
    var repetitionRange: Int?

    // Chat Settings
    var forceThinking: Bool = false // KoboldAPI only
    var disableReasoning: Bool = false
    var resetDeleteMe: Bool = false
    var userTemplates: OrderedDictionary<String, TemplateModel> = [:]
}

extension ConnectionSettingsModel {

    static let defaults = ConnectionSettingsModel(
        host: "127.0.0.1",
        port: 5001,
        connectionType: .KoboldAPI,
        contextLength: 6144,
        maxContextLength: 25600,
        responseLength: 300,
        selectedModel: "deepseek/deepseek-chat-v3-0324:free",
        temperature: 1.15,
        topP: 0,
        topK: 40,
        typicalP: 0,
        repetitionPenalty: 1.18,
        repetitionRange: 64, 
        userTemplates: defaultUserTemplates
    )

    static let defaultUserTemplates: OrderedDictionary<String, TemplateModel> = [
        "Roleplay": TemplateModel(content: TemplatePrompts().defaultRolePlayPrompt, isEnabled: true),
        "Reasoning": TemplateModel(content: TemplateInstructions().reasoningInstructions, isEnabled: true)
    ]
}
