//
//  ChatListViewModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import Foundation
import SwiftLLMSDK

enum APITypeSelection {
    case KoboldAPI
}

@Observable
class ConnectionSettingsViewModel {
    private let serviceContainer = ServiceContainer.shared

    var apiTypeSelection: APITypeSelection = .KoboldAPI

    // Model Settings
    var host: String? 
    var port: Int?
    var contextLength: Int?
    var responseLength: Int?

    var modelName: String?
    var connected: Bool = false

    func connect() async {
        guard let host = host, let port = port else {
            print("Host and port are required")
            return
        }
        
        // Set service container connection settings - there has to be a better way to do this.
        serviceContainer.host = host
        serviceContainer.port = port
        serviceContainer.contextLength = self.contextLength
        serviceContainer.tokenResponseLength = self.responseLength
        
        if await serviceContainer.connectToLanguageModel(host: host, port: port) {
            self.connected = serviceContainer.isConnected
            self.modelName = serviceContainer.modelName
        }
    }
}
