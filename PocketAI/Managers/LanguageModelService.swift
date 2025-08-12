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
    
    func sendStreamedMessage(chatModel: ChatModel, continued: Bool = false) -> AsyncStream<ModelResponse> {
                
        // Map our internal message model to the request body message
        var requestMessages = chatModel.messages.map { message in
            let role: OpenRouterMessageRole = message.actor.rawValue == 0 ? .user : .assistant
            return RequestBodyMessages(role: role, message: message.text)
        }
        
        // If we are continueing a message, we need to add special instructions to the system message.
        // If we are not continuing but the message is loading, we can assume we are regenerating the same message.
        // Pulled this instruction from SillyTavern.
        if connectionSettings.connectionType == .OpenRouter {
            if continued {
                guard let lastMessage = requestMessages.last?.message else {
                    print("No last message")
                    return AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                let continueMessage = TemplateInstructions().continueMessage(lastMessage)
                requestMessages.append(RequestBodyMessages(role: .system, message: continueMessage))
            } else if chatModel.messages.last?.loading ?? false {
                requestMessages.removeLast()
            }
        }

        let (stream, continueation) = AsyncStream<ModelResponse>.makeStream()
        var streamResponse: AsyncStream<Result<ModelResponse, APIError>>
        
        switch connectionSettings.connectionType {
        case .KoboldAPI:
            guard let koboldManager = koboldManager else {
                fatalError("KoboldManager not connected")
            }
            
            let promptBuilder = KoboldRequestBuilder(
                prompt: chatModel.getFullPrompt(continueResponse: continued, enableThinking: true),
                memory: chatModel.getFullMemory(),
                maxContextLength: connectionSettings.contextLength ?? 4096,
                maxLength: connectionSettings.responseLength ?? 240,
                promptTemplate: TemplatePrompts().defaultRolePlayPrompt
            )
            
            streamResponse = koboldManager.streamMessage(builder: promptBuilder)
        case .OpenRouter:
            guard let openRouterManager = openRouterManager else {
                fatalError("OpenRouterManager not connected")
            }
            
            let promptBuilder = OpenRouterRequestBuilder(
                model: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
                messages: requestMessages,
                maxTokens: connectionSettings.responseLength ?? 240,
                stream: true,
                systemPromptTemplate: TemplatePrompts().defaultRolePlayPrompt,
                characterDescription: chatModel.characterCard.first?.description,
                characterPersonality: chatModel.characterCard.first?.personality,
                characterScenario: chatModel.characterCard.first?.scenario
            )
            
            streamResponse = openRouterManager.streamMessage(builder: promptBuilder)
        }
        Task.detached(priority: .medium) {
            for await response in streamResponse {
                switch response {
                case .success(let modelResponse):
                    var modelResponse = modelResponse
                    // Hacky way to remove the need of deltas... which would be beter long term but I'm a lazy bum
                    if continued {
                        modelResponse.text = "\(chatModel.messages.last!.text) \(modelResponse.text ?? "")"
                    }
                    continueation.yield(modelResponse)
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
        return stream
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
        // Pulled this instruction from SillyTavern.
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
        
        var serviceResponse: Result<ModelResponse, APIError>?
        
        switch connectionSettings.connectionType {
        case .KoboldAPI:
            let promptBuilder = KoboldRequestBuilder(
                prompt: chatModel.getFullPrompt(continueResponse: continued, enableThinking: true),
                memory: chatModel.getFullMemory(),
                maxContextLength: connectionSettings.contextLength ?? 4096,
                maxLength: connectionSettings.responseLength ?? 240,
                promptTemplate: TemplatePrompts().defaultRolePlayPrompt
            )
            
            serviceResponse = await koboldManager?.sendMessage(builder: promptBuilder)
        case .OpenRouter:
            let promptBuilder = OpenRouterRequestBuilder(
                model: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
                messages: requestMessages,
                maxTokens: connectionSettings.responseLength ?? 240,
                stream: false,
                systemPromptTemplate: TemplatePrompts().defaultRolePlayPrompt,
                characterDescription: chatModel.characterCard.first?.description,
                characterPersonality: chatModel.characterCard.first?.personality,
                characterScenario: chatModel.characterCard.first?.scenario
            )
            
            serviceResponse = await openRouterManager?.sendMessage(builder: promptBuilder)
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
