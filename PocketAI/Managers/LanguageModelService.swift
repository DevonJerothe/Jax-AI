//
//  LanguageModelService.swift
//  PocketAI
//
//  Created by devon jerothe on 5/23/25.
//

import Foundation
import SwiftLLMSDK

@Observable
final class LanguageModelService {
    private var runtimeConnectionSettings: ConnectionSettingsModel
    var koboldManager: APIManager<KoboldAPI>?
    var openRouterManager: APIManager<OpenRouterAPI>?
    
    var selectedModel: String?
    var availableModels: [OpenRouterModel] = []
    var maxContextLength: Int = 26000

    init(initialConnectionSettings: ConnectionSettingsModel) {
        self.runtimeConnectionSettings = initialConnectionSettings

        setupManagers()
    }

    private func setupManagers() {
        guard let host = runtimeConnectionSettings.host, let port = runtimeConnectionSettings.port else {
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
        
        let openRouterModel = runtimeConnectionSettings.selectedModel
        self.openRouterManager = .init(
            forService: OpenRouterAPI(
                urlSession: URLSession.shared,
                selectedModel: openRouterModel,
                apiKey: runtimeConnectionSettings.apiKey
            )
        )
        
        if runtimeConnectionSettings.connectionType == .OpenRouter {
            self.selectedModel = openRouterModel
        }
    }

    func connect() async -> Bool {
        print("Connecting to \(runtimeConnectionSettings.connectionType)")
        print("Current Context Length: \(runtimeConnectionSettings.contextLength ?? 0)")
        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:
            let result = await koboldManager?.connect()
            switch result {
            case .success(let name):

                // Set Max Context Length 
                let result = await getMaxContextLength()
                self.maxContextLength = result ?? 26000

                self.selectedModel = name
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
                return true
            case .failure(let error):
                print("Error: \(error)")
            case .none:
                print("ERROR: Unexpected Error")
            }
        }
        return false
    }

    func disconnect() {
        selectedModel = nil
    }
    
    func sendStreamedMessage(chatModel: ChatModel, continued: Bool = false, trimmedPrompt: String) -> AsyncStream<ModelResponse> {
        // Map our internal message model to the request body message
        var requestMessages = chatModel.messages.map { message in
            let role: OpenRouterMessageRole = message.actor.rawValue == 0 ? .user : .assistant
            return RequestBodyMessages(role: role, message: message.text)
        }
        
        // If we are continueing a message, we need to add special instructions to the system message.
        // If we are not continuing but the message is loading, we can assume we are regenerating the same message.
        // Pulled this instruction from SillyTavern.
        if runtimeConnectionSettings.connectionType == .OpenRouter {
            if continued {
                guard let lastMessage = requestMessages.last?.message else {
                    return AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                let continueMessage = TemplateInstructions().continueMessage(lastMessage)
                requestMessages.append(RequestBodyMessages(role: .system, message: continueMessage))
            } else if chatModel.messages.last?.status != .done {
                requestMessages.removeLast()
            }
        }

        let (stream, continueation) = AsyncStream<ModelResponse>.makeStream()
        var streamResponse: AsyncStream<Result<ModelResponse, APIError>>
        
        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:
            guard let koboldManager = koboldManager else {
                fatalError("KoboldManager not connected")
            }

            print("Templates used: \(runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n"))") 
            
            let promptBuilder = KoboldRequestBuilder(
                prompt: trimmedPrompt,
                memory: chatModel.getFullMemory(),
                maxContextLength: runtimeConnectionSettings.contextLength ?? 4096,
                maxLength: runtimeConnectionSettings.responseLength ?? 240,
                temperature: runtimeConnectionSettings.temperature ?? 1.15,
                promptTemplate: continued ? "" : runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n")
            )
            
            streamResponse = koboldManager.streamMessage(builder: promptBuilder)
        case .OpenRouter:
            guard let openRouterManager = openRouterManager else {
                fatalError("OpenRouterManager not connected")
            }
            
            let promptBuilder = OpenRouterRequestBuilder(
                model: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
                messages: requestMessages,
                maxTokens: runtimeConnectionSettings.responseLength ?? 240,
                stream: true,
                systemPromptTemplate: TemplatePrompts().defaultRolePlayPrompt,
                characterDescription: chatModel.characterCards.first?.description,
                characterPersonality: chatModel.characterCards.first?.personality,
                characterScenario: chatModel.characterCards.first?.scenario
            )
            
            streamResponse = openRouterManager.streamMessage(builder: promptBuilder)
        }
        Task.detached(priority: .medium) {
            defer { continueation.finish() }
        
            for await response in streamResponse {
                switch response {
                case .success(let modelResponse):
                    var modelResponse = modelResponse
                    // Hacky way to remove the need of deltas... which would be beter long term but I'm a lazy bum
                    if continued {
                        modelResponse.text = "\(chatModel.messages.last!.text) \(modelResponse.text ?? "")"
                    }
                    continueation.yield(modelResponse)
                case .failure(_):
                    let errorResponse = ModelResponse(              
                        role: "assistant",
                        text: "There was an error processing your request. Please try again later.",
                        disconnect: true
                    )
                    continueation.yield(errorResponse)
                    return
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
        if runtimeConnectionSettings.connectionType == .OpenRouter {
            if continued {
                guard let lastMessage = requestMessages.last?.message else {
                    print("No last message")
                    return nil
                }
                let continueMessage = TemplateInstructions().continueMessage(lastMessage)
                requestMessages.append(RequestBodyMessages(role: .system, message: continueMessage))
            } else if chatModel.messages.last?.status != .done {
                requestMessages.removeLast()
            }
        }
        
        var serviceResponse: Result<ModelResponse, APIError>?
        
        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:
            print("Templates used: \(runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n"))")        

            let promptBuilder = KoboldRequestBuilder(
                prompt: await autoTrimFullPrompt(
                    for: chatModel,
                    continueResponse: continued,
                    forceThinking: runtimeConnectionSettings.forceThinking
                ),
                memory: chatModel.getFullMemory(),
                maxContextLength: runtimeConnectionSettings.contextLength ?? 4096,
                maxLength: runtimeConnectionSettings.responseLength ?? 240,
                temperature: runtimeConnectionSettings.temperature ?? 1.15,
                promptTemplate: runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n")
            )
            
            serviceResponse = await koboldManager?.sendMessage(builder: promptBuilder)
        case .OpenRouter:
            let promptBuilder = OpenRouterRequestBuilder(
                model: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
                messages: requestMessages,
                maxTokens: runtimeConnectionSettings.responseLength ?? 240,
                stream: false,
                systemPromptTemplate: TemplatePrompts().defaultRolePlayPrompt,
                characterDescription: chatModel.characterCards.first?.description,
                characterPersonality: chatModel.characterCards.first?.personality,
                characterScenario: chatModel.characterCards.first?.scenario
            )
            
            serviceResponse = await openRouterManager?.sendMessage(builder: promptBuilder)
        }
        
        switch serviceResponse {
        case .success(let model):
            return model
        case .failure(_):
            let errorResponse = ModelResponse(
                role: "assistant",
                text: "There was an error processing your request. Please try again later.",
                disconnect: true
            )
            return errorResponse
        default:
            let errorResponse = ModelResponse(
                role: "assistant",
                text: "There was an error processing your request. Please try again later.",
                disconnect: true
            )
            return errorResponse
        }
    }

    /// Updates the service's runtime settings and refreshes API managers when the
    /// connection identity changes.
    func updateConnectionSettings(_ newConnectionSettings: ConnectionSettingsModel) {
        if newConnectionSettings.host != runtimeConnectionSettings.host ||
            newConnectionSettings.port != runtimeConnectionSettings.port ||
            newConnectionSettings.apiKey != runtimeConnectionSettings.apiKey ||
            newConnectionSettings.selectedModel != runtimeConnectionSettings.selectedModel ||
            newConnectionSettings.connectionType != runtimeConnectionSettings.connectionType {
            self.runtimeConnectionSettings = newConnectionSettings
            setupManagers()
        } else {
            self.runtimeConnectionSettings = newConnectionSettings
        }
    } 

    // MARK: - Kobold Functions
    func getMaxContextLength() async -> Int? {
        guard let manager = koboldManager else {
            print("No Kobold Manager")
            return nil
        }
        let result = await manager.getMaxContextLength()
        switch result {
        case .success(let maxContextLength):
            return maxContextLength
        case .failure(let error):
            print("Error: \(error)")
            return nil
        }
    }

    func getTokenCount(string: String) async -> Int {
        guard let manager = koboldManager else {
            print("No Kobold Manager")
            return 0
        }
        let result = await manager.countTokens(text: string)
        switch result {
        case .success(let tokenCount):
            return tokenCount
        case .failure(let error):
            print("Error: \(error)")
            return 0
        }
    }

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

    private func autoTrimFullPrompt(
        for chatModel: ChatModel,
        continueResponse: Bool = false,
        forceThinking: Bool = false
    ) async -> String {

        let settings = runtimeConnectionSettings
        
        // We only handle context for KoboldAPI until we can include a token counter in app.
        guard settings.connectionType == .KoboldAPI else {
            return ""
        }

        let maxContextTokens = runtimeConnectionSettings.contextLength ?? 4096
        let reservedResponseTokens = runtimeConnectionSettings.responseLength ?? 240
        let memory = chatModel.getFullMemory()
        let memoryTokens = await getTokenCount(string: memory)
        let userTemplates = runtimeConnectionSettings.userTemplates.values
            .filter(\.isEnabled)
            .map(\.content)
            .joined(separator: "\n")
        let systemTokens = await getTokenCount(string: userTemplates)

        var prefix = "\nAssistant: "
        if forceThinking {
            prefix += "<think>\nOk, first we need to consider who we are and not to speak for the user."
        }

        let prefixTokens = await getTokenCount(string: prefix)
        var fixedOverhead = memoryTokens + prefixTokens + reservedResponseTokens
        if continueResponse {
            fixedOverhead += systemTokens
        }

        /// TODO: this is broken. memory will contain our character context. If we 
        /// over context at this point, this will not send any of our messages including the recent one. 
        /// We need to at a minimum return the last two messages or the bot will have 0 conversation history.
        if fixedOverhead >= maxContextTokens {
            return prefix
        }

        struct Block {
            let text: String
            let tokens: Int
        }

        let lastUserID = chatModel.messages.last(where: { $0.actor == .user })?.id

        var blocks: [Block] = []
        for message in chatModel.messages {
            switch message.actor {
            case .user:
                var text = "\(message.text)\nAssistant: "
                if forceThinking && message.id == lastUserID {
                    text += "<think>\nOk, first we need to consider who we are and not to speak for the user."
                }

                let tokens = await getTokenCount(string: text)
                blocks.append(Block(text: text, tokens: tokens))
            case .bot:
                if message.status == .done || continueResponse {
                    let suffix = continueResponse ? "" : "\nUser:"
                    let text = "\(message.text)\(suffix)"
                    let tokens = await getTokenCount(string: text)
                    blocks.append(Block(text: text, tokens: tokens))
                }
            }
        }

        var remaining = maxContextTokens - fixedOverhead
        var selectedReversed: [Block] = []

        for block in blocks.reversed() {
            if block.tokens <= remaining {
                selectedReversed.append(block)
                remaining -= block.tokens
            } else {
                break
            }
        }

        // return selectedReversed
        //     .reversed()
        //     .reduce(prefix) { partialResult, block in
        //         partialResult + block.text
        //     }
        selectedReversed = selectedReversed.reversed()
        var prompt = "" 
        for block in selectedReversed {
            prompt += block.text
        }
        return prompt
    }
}
