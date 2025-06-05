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
    var availableModels: [OpenRouterModel] = []
    var isConnected: Bool = false
    var isLoadingConnection: Bool = false

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
        self.isLoadingConnection = true
        switch connectionSettings.connectionType {
        case .KoboldAPI:
            let result = await koboldManager?.connect()
            switch result {
            case .success(let name):
                self.selectedModel = name
                self.isConnected = true
                self.isLoadingConnection = false
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
                self.isLoadingConnection = false
                return true
            case .failure(let error):
                print("Error: \(error)")
            case .none:
                print("ERROR: Unexpected Error")
            }
        }
        self.isConnected = false
        self.isLoadingConnection = false
        return false
    }
    
    // Put all context switching of service type in this class and out of the view models.
    func sendMessage(chatModel: ChatModel, continued: Bool = false) async -> ModelResponse? {
        
        // Map our internal message model to the request body message
        var requestMessages = chatModel.messages.map { message in
            let role: OpenRouterMessageRole = message.actor.rawValue == 0 ? .user : .assistant
            return RequestBodyMessages(role: role, message: message.text)
        }
        
        // If we are continueing a message, we need to add special instructions to the system message.
        // If we are not continuing but the message is loading, we can assume we are regenerating the same message.
        // Pulled this method from SillyTavern.
        if connectionSettings.connectionType == .OpenRouter {
            if continued {
                guard let lastMessage = requestMessages.last?.message else {
                    print("No last message")
                    return nil
                }
                let continueMessage = TemplateInstructions().continueMessage(lastMessage)
                requestMessages.append(RequestBodyMessages(role: .system, message: continueMessage))
            } else if chatModel.messages.last?.loading ?? false {
                requestMessages.removeLast()
            }
        }
        
        // TODO: Add Character Card info for OpenRouter
        let requestBuilder = RequestBodyBuilder(
            selectedModel: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
            messages: requestMessages,
            memory: chatModel.getFullMemory(),
            prompt: chatModel.getFullPrompt(continueResponse: continued),
            maxContextLength: connectionSettings.contextLength ?? 4096,
            maxLength: connectionSettings.responseLength ?? 240,
            promptTemplate: TemplatePrompts().defaultRolePlayPrompt,
            characterDescription: chatModel.characterCard.first?.description,
            characterPersonality: chatModel.characterCard.first?.personality,
            characterScenario: chatModel.characterCard.first?.scenario
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
        self.isConnected = false
        self.connectionSettings = connectionSettings
        setupManagers()
    }

    // MARK: - Kobold Functions

    // MARK: - OpenRouter Functions
    func getAvailableModels() async {
        guard let manager = openRouterManager else {
            print("No OpenRouter Manager")
            return
        }
        let result = await manager.getAvailableModels()
        switch result {
        case .success(let models):
            self.availableModels = models
        case .failure(let error):
            print("Error: \(error)")
        }
    }
}
