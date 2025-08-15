//
//  ConnectionSettingsModel.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//


enum APITypeSelection: String, Codable {
    case KoboldAPI
    case OpenRouter
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
    
    static let defaults = ConnectionSettingsModel(
        host: "127.0.0.1",
        port: 5001,
        connectionType: .KoboldAPI,
        contextLength: 6144,
        maxContextLength: 25600,
        responseLength: 300,
        selectedModel: "deepseek/deepseek-chat-v3-0324:free"
    )
}
