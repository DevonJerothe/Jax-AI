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
    var temperature: Double
    var topP: Double
    var topK: Double
    var typicalP: Double
    var tfs: Int
    var topA: Double
    var minP: Double
    var repetitionPenalty: Double
    var repetitionRange: Int
    var repetitionSlope: Double
    var samplerOrder: [Int]
    var userStopSequence: String 
    var botStopSequence: String 
    var systemStopSequence: String 
    var thinkingStartSequence: String
    var thinkingStopSequence: String
    var forceThinkingInstruct: String

    // Chat Settings
    var forceThinking: Bool = false // KoboldAPI only
    var disableReasoning: Bool = false
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
        temperature: Double = 0.9,
        topP: Double = 0.95,
        topK: Double = 40,
        typicalP: Double = 1,
        tfs: Int = 1,
        topA: Double = 0,
        minP: Double = 0,
        repetitionPenalty: Double = 1.1,
        repetitionRange: Int = 360,
        repetitionSlope: Double = 0.5,
        samplerOrder: [Int] = [6, 0, 1, 3, 4, 2, 5],
        forceThinking: Bool = false,
        disableReasoning: Bool = false,
        resetDeleteMe: Bool = false,
        userTemplates: OrderedDictionary<String, TemplateModel> = [:],
        locked: Bool = false,
        autoLock: Bool = false,
        autoConnect: Bool = false,
        userStopSequence: String = ConnectionSettingsModel.defaultUserStopSequence,
        botStopSequence: String = ConnectionSettingsModel.defaultBotStopSequence,
        systemStopSequence: String = ConnectionSettingsModel.defaultSystemStopSequence,
        thinkingStartSequence: String = ConnectionSettingsModel.defaultThinkingStartSequence,
        thinkingStopSequence: String = ConnectionSettingsModel.defaultThinkingStopSequence,
        forceThinkingInstruct: String = ConnectionSettingsModel.defaultForceThinkingInstruct
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
        self.tfs = tfs
        self.topA = topA
        self.minP = minP
        self.repetitionPenalty = repetitionPenalty
        self.repetitionRange = repetitionRange
        self.repetitionSlope = repetitionSlope
        self.samplerOrder = samplerOrder
        self.forceThinking = forceThinking
        self.disableReasoning = disableReasoning
        self.userTemplates = userTemplates
        self.locked = locked
        self.autoLock = autoLock
        self.autoConnect = autoConnect
        self.userStopSequence = userStopSequence
        self.botStopSequence = botStopSequence
        self.systemStopSequence = systemStopSequence
        self.thinkingStartSequence = thinkingStartSequence
        self.thinkingStopSequence = thinkingStopSequence
        self.forceThinkingInstruct = forceThinkingInstruct
        self.ensureNonEmptySequences()
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
        case tfs
        case topA
        case minP
        case repetitionPenalty
        case repetitionRange
        case repetitionSlope
        case samplerOrder
        case forceThinking
        case disableReasoning
        case userTemplates
        case locked
        case autoLock
        case autoConnect
        case userStopSequence
        case botStopSequence
        case systemStopSequence
        case thinkingStartSequence
        case thinkingStopSequence
        case forceThinkingInstruct
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ConnectionSettingsModel.defaults

        self.host = try container.decodeIfPresent(String.self, forKey: .host)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port)
        self.connectionType = try container.decodeIfPresent(APITypeSelection.self, forKey: .connectionType) ?? .KoboldAPI
        self.contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        self.maxContextLength = try container.decodeIfPresent(Int.self, forKey: .maxContextLength)
        self.responseLength = try container.decodeIfPresent(Int.self, forKey: .responseLength)
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        self.selectedModel = try container.decodeIfPresent(String.self, forKey: .selectedModel)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? defaults.temperature
        self.topP = try container.decodeIfPresent(Double.self, forKey: .topP) ?? defaults.topP
        self.topK = try container.decodeIfPresent(Double.self, forKey: .topK) ?? defaults.topK
        self.typicalP = try container.decodeIfPresent(Double.self, forKey: .typicalP) ?? defaults.typicalP
        self.tfs = try container.decodeIfPresent(Int.self, forKey: .tfs) ?? defaults.tfs
        self.topA = try container.decodeIfPresent(Double.self, forKey: .topA) ?? defaults.topA
        self.minP = try container.decodeIfPresent(Double.self, forKey: .minP) ?? defaults.minP
        self.repetitionPenalty = try container.decodeIfPresent(Double.self, forKey: .repetitionPenalty) ?? defaults.repetitionPenalty
        self.repetitionRange = try container.decodeIfPresent(Int.self, forKey: .repetitionRange) ?? defaults.repetitionRange
        self.repetitionSlope = try container.decodeIfPresent(Double.self, forKey: .repetitionSlope) ?? defaults.repetitionSlope
        self.samplerOrder = try container.decodeIfPresent([Int].self, forKey: .samplerOrder) ?? defaults.samplerOrder
        self.forceThinking = try container.decodeIfPresent(Bool.self, forKey: .forceThinking) ?? false
        self.disableReasoning = try container.decodeIfPresent(Bool.self, forKey: .disableReasoning) ?? false
        self.userTemplates = try container.decodeIfPresent(OrderedDictionary<String, TemplateModel>.self, forKey: .userTemplates) ?? [:]
        self.locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        self.autoLock = try container.decodeIfPresent(Bool.self, forKey: .autoLock) ?? false
        self.autoConnect = try container.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? false
        self.userStopSequence = try container.decodeIfPresent(String.self, forKey: .userStopSequence) ?? defaults.userStopSequence
        self.botStopSequence = try container.decodeIfPresent(String.self, forKey: .botStopSequence) ?? defaults.botStopSequence
        self.systemStopSequence = try container.decodeIfPresent(String.self, forKey: .systemStopSequence) ?? defaults.systemStopSequence
        self.thinkingStartSequence = try container.decodeIfPresent(String.self, forKey: .thinkingStartSequence) ?? defaults.thinkingStartSequence
        self.thinkingStopSequence = try container.decodeIfPresent(String.self, forKey: .thinkingStopSequence) ?? defaults.thinkingStopSequence
        self.forceThinkingInstruct = try container.decodeIfPresent(String.self, forKey: .forceThinkingInstruct) ?? defaults.forceThinkingInstruct
        self.ensureNonEmptySequences()
    }
}

extension ConnectionSettingsModel {
    static let defaultUserStopSequence = "\nUser:"
    static let defaultBotStopSequence = "\nAssistant:"
    static let defaultSystemStopSequence = "\nSystem:"
    static let defaultThinkingStartSequence = "<think>"
    static let defaultThinkingStopSequence = "</think>"
    static let defaultForceThinkingInstruct = "Ok, first we need to consider who we are and not to speak for the user."

    static let defaults = ConnectionSettingsModel(
        host: "127.0.0.1",
        port: 5001,
        connectionType: .KoboldAPI,
        contextLength: 6144,
        maxContextLength: 25600,
        responseLength: 300,
        selectedModel: "deepseek/deepseek-chat-v3-0324:free",
        temperature: 0.9,
        topP: 0.95,
        topK: 40,
        typicalP: 1,
        tfs: 1,
        topA: 0,
        minP: 0,
        repetitionPenalty: 1.1,
        repetitionRange: 360,
        repetitionSlope: 0.5,
        samplerOrder: [6, 0, 1, 3, 4, 2, 5],
        userTemplates: defaultUserTemplates,
        userStopSequence: defaultUserStopSequence,
        botStopSequence: defaultBotStopSequence,
        systemStopSequence: defaultSystemStopSequence,
        thinkingStartSequence: defaultThinkingStartSequence,
        thinkingStopSequence: defaultThinkingStopSequence,
        forceThinkingInstruct: defaultForceThinkingInstruct
    )

    static let defaultUserTemplates: OrderedDictionary<String, TemplateModel> = [
        "Roleplay": TemplateModel(content: TemplatePrompts().defaultRolePlayPrompt, isEnabled: true),
        "Reasoning": TemplateModel(content: TemplateInstructions().reasoningInstructions, isEnabled: true)
    ]

    mutating func ensureNonEmptySequences() {
        userStopSequence = Self.nonEmptySequence(
            userStopSequence,
            fallback: Self.defaultUserStopSequence
        )
        botStopSequence = Self.nonEmptySequence(
            botStopSequence,
            fallback: Self.defaultBotStopSequence
        )
        systemStopSequence = Self.nonEmptySequence(
            systemStopSequence,
            fallback: Self.defaultSystemStopSequence
        )
        thinkingStartSequence = Self.nonEmptySequence(
            thinkingStartSequence,
            fallback: Self.defaultThinkingStartSequence
        )
        thinkingStopSequence = Self.nonEmptySequence(
            thinkingStopSequence,
            fallback: Self.defaultThinkingStopSequence
        )
        forceThinkingInstruct = Self.nonEmptySequence(
            forceThinkingInstruct,
            fallback: Self.defaultForceThinkingInstruct
        )
    }

    private static func nonEmptySequence(_ sequence: String, fallback: String) -> String {
        sequence.isEmpty ? fallback : sequence
    }
}
