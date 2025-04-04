//
//  ConnectionSettingsModel.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//


enum APITypeSelection: String, Codable {
    case KoboldAPI
}

public struct ConnectionSettingsModel: Codable {
    var host: String?
    var port: Int?
    var connectionType: APITypeSelection = .KoboldAPI
    var contextLength: Int?
    var responseLength: Int?
    
    static let defaults = ConnectionSettingsModel(
        host: "127.0.0.1",
        port: 5001,
        connectionType: .KoboldAPI,
        contextLength: 6144,
        responseLength: 300
    )
}
