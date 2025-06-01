//
//  LanguageModelService.swift
//  PocketAI
//
//  Created by devon jerothe on 5/23/25.
//

import Foundation
import SwiftLLMSDK

@Observable
class LanguageModelService {
    // static let shared =  LanguageModelService()

    var connectionSettings: ConnectionSettingsModel
    var koboldManager: APIManager<KoboldAPI>?
    var openRouterManager: APIManager<OpenRouterAPI>?
    var selectedModel: String?
    var isConnected: Bool = false

    init(connectionSettings: ConnectionSettingsModel) {
        self.connectionSettings = connectionSettings

        setupManagers()
    }

    private func setupManagers() {
        guard let host = connectionSettings.host, let port = connectionSettings.port else {
            print("No Connection Settings")
            return
        }
        
        self.koboldManager = .init(
            forService: KoboldAPI(
                urlSession: URLSession.shared,
                host: host,
                port: port
            )
        )
        
        let openRouterModel = connectionSettings.selectedModel
        self.openRouterManager = .init(
            forService: OpenRouterAPI(
                urlSession: URLSession.shared,
                selectedModel: openRouterModel,
                apiKey: connectionSettings.apiKey
            )
        )
        
        if connectionSettings.connectionType == .OpenRouter {
            self.selectedModel = openRouterModel
        }
    }

    func connect() async -> Bool {
        switch connectionSettings.connectionType {
        case .KoboldAPI:
            let result = await koboldManager?.connect()
            switch result {
            case .success(let name):
                self.selectedModel = name
                self.isConnected = true
                return true
            case .failure(let error):
                print("Error: \(error)")
            case .none:
                print("ERROR: Unexpected Error")
            }
        case .OpenRouter:
            let result = await openRouterManager?.connect()
            switch result {
            case .success(_):
                self.isConnected = true
                return true
            case .failure(let error):
                print("Error: \(error)")
            case .none:
                print("ERROR: Unexpected Error")
            }
        }
        self.isConnected = false
        return false
    }
    
    // Put all context switching of service type in this class and out of the view models.
    func sendMessage(chatModel: ChatModel, continued: Bool = false) async -> ModelResponse? {
        
        // Map our internal message model to the request body message
        let requestMessages = chatModel.messages.map { message in
            let role: OpenRouterMessageRole = message.actor.rawValue == 0 ? .user : .assistant
            return RequestBodyMessages(role: role, message: message.text)
        }
        
        // TODO: Add Character Card info for OpenRouter
        let requestBuilder = RequestBodyBuilder(
            selectedModel: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
            messages: requestMessages,
            memory: chatModel.getFullMemory(),
            prompt: chatModel.getFullPrompt(continueResponse: continued),
            maxContextLength: connectionSettings.contextLength ?? 4096,
            maxLength: connectionSettings.responseLength ?? 240,
            promptTemplate: TemplatePrompts().defaultRolePlayPrompt
        )
        
        var serviceResponse: Result<ModelResponse, APIError>?
        
        switch connectionSettings.connectionType {
        case .KoboldAPI:
            serviceResponse = await koboldManager?.sendMessage(promptModel: requestBuilder)
        case .OpenRouter:
            serviceResponse = await openRouterManager?.sendMessage(promptModel: requestBuilder)
        }
        
        switch serviceResponse {
        case .success(let model):
            return model
        case .failure(let error):
            print("ERROR: \(error)")
        default:
            print("ERROR: Unexpected Error")
        }
        
        // If we get here then no response was passed. This is ugly... and should be reworked.
        // honestly this whole app needs to be reworked....
        return nil
    }
        

    func updateConnectionSettings(connectionSettings: ConnectionSettingsModel) {
        self.connectionSettings = connectionSettings
        setupManagers()
    }

    // MARK: - Kobold Functions

    // MARK: - OpenRouter Functions
    func getAvailableModels() async -> [OpenRouterModel] {
        guard let manager = openRouterManager else {
            print("No OpenRouter Manager")
            return []
        }
        let result = await manager.getAvailableModels()
        switch result {
        case .success(let models):
            return models
        case .failure(let error):
            print("Error: \(error)")
            return []
        }
    }
}
