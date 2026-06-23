//
//  ConnectionSettingsModel.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//

import Collections
import SwiftLLMSDK

enum APITypeSelection: String, Codable {
    case KoboldAPI
    case OpenRouter
    case OpenAI
}

protocol ModelPickerItem {
    var id: String { get }
}

extension ModelPickerItem {
    var displayName: String { id }
    var searchableText: String { id }
}

extension OpenRouterModel: ModelPickerItem {
    var displayName: String { name }
    var searchableText: String { "\(name) \(id) \(description)" }
}

extension OpenAIModel: ModelPickerItem {
    var displayName: String { id }
    var searchableText: String { id }
}

public struct TemplateModel: Codable, Equatable {
    var content: String
    var isEnabled: Bool
}

public struct KoboldCPPSettings: Codable {
    var host: String?
    var port: Int?
    var maxContextLength: Int?
    var contextLength: Int?
    var responseLength: Int?
    var selectedModel: String?

    init(
        host: String? = nil,
        port: Int? = nil,
        maxContextLength: Int? = nil,
        contextLength: Int? = nil,
        responseLength: Int? = nil,
        selectedModel: String? = nil
    ) {
        self.host = host
        self.port = port
        self.maxContextLength = maxContextLength
        self.contextLength = contextLength
        self.responseLength = responseLength
        self.selectedModel = selectedModel
    }
}

public struct OpenRouterSettings: Codable {
    var maxContextLength: Int?
    var contextLength: Int?
    var responseLength: Int?
    var apiKey: String?
    var selectedModel: String?

    init(
        maxContextLength: Int? = nil,
        contextLength: Int? = nil,
        responseLength: Int? = nil,
        apiKey: String? = nil,
        selectedModel: String? = nil
    ) {
        self.maxContextLength = maxContextLength
        self.contextLength = contextLength
        self.responseLength = responseLength
        self.apiKey = apiKey
        self.selectedModel = selectedModel
    }
}

public struct OpenAISettings: Codable {
    var baseURL: String?
    var selectedModel: String?
    var apiKey: String?
    var maxContextLength: Int?
    var contextLength: Int?
    var responseLength: Int?

    init(
        baseURL: String? = nil,
        selectedModel: String? = nil,
        apiKey: String? = nil,
        maxContextLength: Int? = nil,
        contextLength: Int? = nil,
        responseLength: Int? = nil
    ) {
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.apiKey = apiKey
        self.maxContextLength = maxContextLength
        self.contextLength = contextLength
        self.responseLength = responseLength
    }
}

public struct ConnectionSettingsModel: Codable {
    var connectionType: APITypeSelection = .KoboldAPI
    var koboldCPPSettings: KoboldCPPSettings?
    var openRouterSettings: OpenRouterSettings?
    var openAISettings: OpenAISettings?

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
    var autoScrollChat: Bool = true
    var forceThinking: Bool = false // KoboldAPI only
    var disableReasoning: Bool = false
    var userTemplates: OrderedDictionary<String, TemplateModel> = [:]

    // App Settings
    var locked: Bool = false 
    var autoLock: Bool = false
    var autoConnect: Bool = false 
    var currentTheme: AppTheme = AppTheme.defaultTheme

    init(
        connectionType: APITypeSelection = .KoboldAPI,
        koboldCPPSettings: KoboldCPPSettings? = nil,
        openRouterSettings: OpenRouterSettings? = nil,
        openAISettings: OpenAISettings? = nil,
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
        autoScrollChat: Bool = true,
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
        forceThinkingInstruct: String = ConnectionSettingsModel.defaultForceThinkingInstruct,
        currentTheme: AppTheme = AppTheme.defaultTheme
    ) {
        self.connectionType = connectionType
        self.koboldCPPSettings = koboldCPPSettings
        self.openRouterSettings = openRouterSettings
        self.openAISettings = openAISettings
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
        self.autoScrollChat = autoScrollChat
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
        self.currentTheme = currentTheme
        self.ensureNonEmptySequences()
    }

    enum CodingKeys: String, CodingKey {
        case connectionType
        case koboldCPPSettings
        case openRouterSettings
        case openAISettings
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
        case autoScrollChat
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
        case currentTheme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ConnectionSettingsModel.defaults

        self.connectionType = try container.decodeIfPresent(APITypeSelection.self, forKey: .connectionType) ?? .KoboldAPI
        self.koboldCPPSettings = try container.decodeIfPresent(KoboldCPPSettings.self, forKey: .koboldCPPSettings)
        self.openRouterSettings = try container.decodeIfPresent(OpenRouterSettings.self, forKey: .openRouterSettings)
        self.openAISettings = try container.decodeIfPresent(OpenAISettings.self, forKey: .openAISettings)
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
        self.autoScrollChat = try container.decodeIfPresent(Bool.self, forKey: .autoScrollChat) ?? true
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
        self.currentTheme = try container.decodeIfPresent(AppTheme.self, forKey: .currentTheme) ?? defaults.currentTheme
        self.ensureNonEmptySequences()
    }

    var activeHost: String? {
        switch connectionType {
        case .KoboldAPI:
            koboldCPPSettings?.host
        case .OpenRouter, .OpenAI:
            nil
        }
    }

    var activePort: Int? {
        switch connectionType {
        case .KoboldAPI:
            koboldCPPSettings?.port
        case .OpenRouter, .OpenAI:
            nil
        }
    }

    var activeMaxContextLength: Int? {
        switch connectionType {
        case .KoboldAPI:
            koboldCPPSettings?.maxContextLength
        case .OpenRouter:
            openRouterSettings?.maxContextLength
        case .OpenAI:
            openAISettings?.maxContextLength
        }
    }

    var activeContextLength: Int? {
        switch connectionType {
        case .KoboldAPI:
            koboldCPPSettings?.contextLength
        case .OpenRouter:
            openRouterSettings?.contextLength
        case .OpenAI:
            openAISettings?.contextLength
        }
    }

    var activeResponseLength: Int? {
        switch connectionType {
        case .KoboldAPI:
            koboldCPPSettings?.responseLength
        case .OpenRouter:
            openRouterSettings?.responseLength
        case .OpenAI:
            openAISettings?.responseLength
        }
    }

    var activeAPIKey: String? {
        switch connectionType {
        case .KoboldAPI:
            nil
        case .OpenRouter:
            openRouterSettings?.apiKey
        case .OpenAI:
            openAISettings?.apiKey
        }
    }

    var activeSelectedModel: String? {
        switch connectionType {
        case .KoboldAPI:
            koboldCPPSettings?.selectedModel
        case .OpenRouter:
            openRouterSettings?.selectedModel
        case .OpenAI:
            openAISettings?.selectedModel
        }
    }

    mutating func updateActiveHost(_ value: String?) {
        var settings = koboldCPPSettings ?? Self.defaultKoboldCPPSettings
        settings.host = value
        koboldCPPSettings = settings
    }

    mutating func updateActivePort(_ value: Int?) {
        var settings = koboldCPPSettings ?? Self.defaultKoboldCPPSettings
        settings.port = value
        koboldCPPSettings = settings
    }

    mutating func updateActiveMaxContextLength(_ value: Int?) {
        switch connectionType {
        case .KoboldAPI:
            var settings = koboldCPPSettings ?? Self.defaultKoboldCPPSettings
            settings.maxContextLength = value
            koboldCPPSettings = settings
        case .OpenRouter:
            var settings = openRouterSettings ?? Self.defaultOpenRouterSettings
            settings.maxContextLength = value
            openRouterSettings = settings
        case .OpenAI:
            var settings = openAISettings ?? Self.defaultOpenAISettings
            settings.maxContextLength = value
            openAISettings = settings
        }
    }

    mutating func updateActiveContextLength(_ value: Int?) {
        switch connectionType {
        case .KoboldAPI:
            var settings = koboldCPPSettings ?? Self.defaultKoboldCPPSettings
            settings.contextLength = value
            koboldCPPSettings = settings
        case .OpenRouter:
            var settings = openRouterSettings ?? Self.defaultOpenRouterSettings
            settings.contextLength = value
            openRouterSettings = settings
        case .OpenAI:
            var settings = openAISettings ?? Self.defaultOpenAISettings
            settings.contextLength = value
            openAISettings = settings
        }
    }

    mutating func updateActiveResponseLength(_ value: Int?) {
        switch connectionType {
        case .KoboldAPI:
            var settings = koboldCPPSettings ?? Self.defaultKoboldCPPSettings
            settings.responseLength = value
            koboldCPPSettings = settings
        case .OpenRouter:
            var settings = openRouterSettings ?? Self.defaultOpenRouterSettings
            settings.responseLength = value
            openRouterSettings = settings
        case .OpenAI:
            var settings = openAISettings ?? Self.defaultOpenAISettings
            settings.responseLength = value
            openAISettings = settings
        }
    }

    mutating func updateActiveAPIKey(_ value: String?) {
        switch connectionType {
        case .KoboldAPI:
            return
        case .OpenRouter:
            var settings = openRouterSettings ?? Self.defaultOpenRouterSettings
            settings.apiKey = value
            openRouterSettings = settings
        case .OpenAI:
            var settings = openAISettings ?? Self.defaultOpenAISettings
            settings.apiKey = value
            openAISettings = settings
        }
    }

    mutating func updateActiveSelectedModel(_ value: String?) {
        switch connectionType {
        case .KoboldAPI:
            var settings = koboldCPPSettings ?? Self.defaultKoboldCPPSettings
            settings.selectedModel = value
            koboldCPPSettings = settings
        case .OpenRouter:
            var settings = openRouterSettings ?? Self.defaultOpenRouterSettings
            settings.selectedModel = value
            openRouterSettings = settings
        case .OpenAI:
            var settings = openAISettings ?? Self.defaultOpenAISettings
            settings.selectedModel = value
            openAISettings = settings
        }
    }
}

extension ConnectionSettingsModel {
    static let defaultUserStopSequence = "\nUser:"
    static let defaultBotStopSequence = "\nAssistant:"
    static let defaultSystemStopSequence = "\nSystem:"
    static let defaultThinkingStartSequence = "<think>"
    static let defaultThinkingStopSequence = "</think>"
    static let defaultForceThinkingInstruct = "Ok, first we need to consider who we are and not to speak for the user."

    static let defaultKoboldCPPSettings = KoboldCPPSettings(
        host: "127.0.0.1",
        port: 5001,
        maxContextLength: 25600,
        contextLength: 6144,
        responseLength: 300,
        selectedModel: nil
    )

    static let defaultOpenRouterSettings = OpenRouterSettings(
        maxContextLength: 256000,
        contextLength: 6144,
        responseLength: 300,
        apiKey: nil,
        selectedModel: "deepseek/deepseek-chat-v3-0324:free"
    )

    static let defaultOpenAISettings = OpenAISettings(
        baseURL: "",
        selectedModel: "",
        apiKey: nil,
        maxContextLength: 256000,
        contextLength: 6144,
        responseLength: 300
    )

    static let defaults = ConnectionSettingsModel(
        connectionType: .KoboldAPI,
        koboldCPPSettings: defaultKoboldCPPSettings,
        openRouterSettings: defaultOpenRouterSettings,
        openAISettings: defaultOpenAISettings,
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
        forceThinkingInstruct: defaultForceThinkingInstruct,
        currentTheme: AppTheme.defaultTheme
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
