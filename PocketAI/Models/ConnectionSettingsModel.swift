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

    // App Settings
    var locked: Bool = false 
    var autoLock: Bool = false
    var autoConnect: Bool = false 

    init(
        host: String? = nil,
        port: Int? = nil,
        connectionType: APITypeSelection = .KoboldAPI,
        contextLength: Int? = nil,
        maxContextLength: Int? = nil,
        responseLength: Int? = nil,
        apiKey: String? = nil,
        selectedModel: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        typicalP: Double? = nil,
        repetitionPenalty: Double? = nil,
        repetitionRange: Int? = nil,
        forceThinking: Bool = false,
        disableReasoning: Bool = false,
        resetDeleteMe: Bool = false,
        userTemplates: OrderedDictionary<String, TemplateModel> = [:],
        locked: Bool = false,
        autoLock: Bool = false,
        autoConnect: Bool = false
    ) {
        self.host = host
        self.port = port
        self.connectionType = connectionType
        self.contextLength = contextLength
        self.maxContextLength = maxContextLength
        self.responseLength = responseLength
        self.apiKey = apiKey
        self.selectedModel = selectedModel
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.typicalP = typicalP
        self.repetitionPenalty = repetitionPenalty
        self.repetitionRange = repetitionRange
        self.forceThinking = forceThinking
        self.disableReasoning = disableReasoning
        self.resetDeleteMe = resetDeleteMe
        self.userTemplates = userTemplates
        self.locked = locked
        self.autoLock = autoLock
        self.autoConnect = autoConnect
    }

    enum CodingKeys: String, CodingKey {
        case host
        case port
        case connectionType
        case contextLength
        case maxContextLength
        case responseLength
        case apiKey
        case selectedModel
        case temperature
        case topP
        case topK
        case typicalP
        case repetitionPenalty
        case repetitionRange
        case forceThinking
        case disableReasoning
        case resetDeleteMe
        case userTemplates
        case locked
        case autoLock
        case autoConnect
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.host = try container.decodeIfPresent(String.self, forKey: .host)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port)
        self.connectionType = try container.decodeIfPresent(APITypeSelection.self, forKey: .connectionType) ?? .KoboldAPI
        self.contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        self.maxContextLength = try container.decodeIfPresent(Int.self, forKey: .maxContextLength)
        self.responseLength = try container.decodeIfPresent(Int.self, forKey: .responseLength)
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        self.selectedModel = try container.decodeIfPresent(String.self, forKey: .selectedModel)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.topP = try container.decodeIfPresent(Double.self, forKey: .topP)
        self.topK = try container.decodeIfPresent(Int.self, forKey: .topK)
        self.typicalP = try container.decodeIfPresent(Double.self, forKey: .typicalP)
        self.repetitionPenalty = try container.decodeIfPresent(Double.self, forKey: .repetitionPenalty)
        self.repetitionRange = try container.decodeIfPresent(Int.self, forKey: .repetitionRange)
        self.forceThinking = try container.decodeIfPresent(Bool.self, forKey: .forceThinking) ?? false
        self.disableReasoning = try container.decodeIfPresent(Bool.self, forKey: .disableReasoning) ?? false
        self.resetDeleteMe = try container.decodeIfPresent(Bool.self, forKey: .resetDeleteMe) ?? false
        self.userTemplates = try container.decodeIfPresent(OrderedDictionary<String, TemplateModel>.self, forKey: .userTemplates) ?? [:]
        self.locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        self.autoLock = try container.decodeIfPresent(Bool.self, forKey: .autoLock) ?? false
        self.autoConnect = try container.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? false
    }
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
