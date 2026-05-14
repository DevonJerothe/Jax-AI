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
        var normalizedSettings = initialConnectionSettings
        normalizedSettings.ensureNonEmptySequences()
        self.runtimeConnectionSettings = normalizedSettings

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
    
    func sendStreamedMessage(
        chatModel: ChatModel,
        userPersona: UserPersonaModel?, 
        continued: Bool = false,
        trimmedPrompt: String
    ) -> AsyncStream<ModelResponse> {
        // Map our internal message model to the request body message
        var requestMessages = chatModel.messages.map { message in
            let role: OpenRouterMessageRole = message.actor.rawValue == 0 ? .user : .assistant
            let messageText = message.text
                .replaceChatSequences(user: userPersona?.name, char: chatModel.chatTitle)
            
            return RequestBodyMessages(role: role, message: messageText)
        }

        for note in chatModel.chatNotes {
            guard note.injectInMemory == false else { continue }
            // ensure index is not negative
            let insertIndex = max(0, requestMessages.count - note.depth)
            let noteText = note.note
                .replaceChatSequences(user: userPersona?.name, char: chatModel.chatTitle)

            let requestMessage = RequestBodyMessages(role: .system, message: noteText)
            requestMessages.insert(requestMessage, at: insertIndex)
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
                // Remove the last user message
                // if we inserted a notes into the last index, we need to remove the bot message before it.
                // At this point we will always have an empty "placeholder" bot message for the loader
                let loaderPlaceholder = requestMessages.last(where: { $0.role == .assistant })
                if let loaderPlaceholder {
                    requestMessages.removeAll(where: { $0.message == loaderPlaceholder.message })
                }
            }
        }

        let (stream, continuation) = AsyncStream<ModelResponse>.makeStream()
        var streamResponse: AsyncStream<Result<ModelResponse, APIError>>
        
        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:
            guard let koboldManager = koboldManager else {
                fatalError("KoboldManager not connected")
            }
            
            let promptBuilder = KoboldRequestBuilder(
                prompt: trimmedPrompt,
                memory: chatModel.getFullMemory(userPersona: userPersona),
                maxContextLength: runtimeConnectionSettings.contextLength ?? 4096,
                maxLength: runtimeConnectionSettings.responseLength ?? 240,
                temperature: runtimeConnectionSettings.temperature,
                tfs: runtimeConnectionSettings.tfs,
                topA: runtimeConnectionSettings.topA,
                topK: runtimeConnectionSettings.topK,
                topP: runtimeConnectionSettings.topP,
                minP: runtimeConnectionSettings.minP,
                typical: Int(runtimeConnectionSettings.typicalP),
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                repetitionRange: runtimeConnectionSettings.repetitionRange,
                repetitionSlope: runtimeConnectionSettings.repetitionSlope,
                stopSequence: stopSequences,
                samplerOrder: runtimeConnectionSettings.samplerOrder,
                promptTemplate: continued ? "" : runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n")
            )
            
            streamResponse = koboldManager.streamMessage(builder: promptBuilder)
        case .OpenRouter:
            guard let openRouterManager = openRouterManager else {
                fatalError("OpenRouterManager not connected")
            }

            // TODO: support sending user persona description
            let promptBuilder = OpenRouterRequestBuilder(
                model: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
                messages: requestMessages,
                stop: stopSequences,
                temperature: runtimeConnectionSettings.temperature,
                topP: runtimeConnectionSettings.topP,
                minP: runtimeConnectionSettings.minP,
                topA: runtimeConnectionSettings.topA,
                topK: runtimeConnectionSettings.topK,
                maxTokens: runtimeConnectionSettings.responseLength ?? 240,
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                stream: true,
                systemPromptTemplate: runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n"),
                characterDescription: chatModel.characterCards.first?.description?.replaceChatSequences(
                    user: userPersona?.name,
                    char: chatModel.chatTitle
                ),
                characterPersonality: chatModel.characterCards.first?.personality?.replaceChatSequences(
                    user: userPersona?.name,
                    char: chatModel.chatTitle
                ),
                characterScenario: chatModel.characterCards.first?.scenario?.replaceChatSequences(
                    user: userPersona?.name,
                    char: chatModel.chatTitle
                )
            )
            
            streamResponse = openRouterManager.streamMessage(builder: promptBuilder)
        }
        Task.detached(priority: .medium) {
            defer { continuation.finish() }
        
            for await response in streamResponse {
                switch response {
                case .success(let modelResponse):
                    continuation.yield(modelResponse)
                case .failure(_):
                    let errorResponse = ModelResponse(              
                        role: "assistant",
                        text: "There was an error processing your request. Please try again later.",
                        disconnect: true
                    )
                    continuation.yield(errorResponse)
                    return
                }
            }         
        }
        return stream
    }
    
    // Put all context switching of service type in this class and out of the view models.
    func sendMessage(chatModel: ChatModel, continued: Bool = false) async -> ModelResponse? {
        let userPersona = await ServiceContainer.shared.getPersona
        
        // Map our internal message model to the request body message
        var requestMessages = chatModel.messages.map { message in
            let role: OpenRouterMessageRole = message.actor.rawValue == 0 ? .user : .assistant
            let messageText = message.text
                .replaceChatSequences(user: userPersona?.name, char: chatModel.chatTitle)
            return RequestBodyMessages(role: role, message: messageText)
        }
        
        for note in chatModel.chatNotes {
            guard note.injectInMemory == false else { continue }
            // ensure index is not negative
            let insertIndex = max(0, requestMessages.count - note.depth)
            let noteText = note.note
                .replaceChatSequences(user: userPersona?.name, char: chatModel.chatTitle)

            let requestMessage = RequestBodyMessages(role: .system, message: noteText)
            requestMessages.insert(requestMessage, at: insertIndex)
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
                // Remove the last user message
                // if we inserted a notes into the last index, we need to remove the bot message before it.
                let loaderPlaceholder = requestMessages.last(where: { $0.role == .assistant })
                if let loaderPlaceholder {
                    requestMessages.removeAll(where: { $0.message == loaderPlaceholder.message })
                }
            }
        }
        
        var serviceResponse: Result<ModelResponse, APIError>?
        
        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:
            print("Templates used: \(runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n"))")        
            let promptContext = await KoboldPromptContextBuilder(
                tokenCount: { [weak self] text in
                    await self?.getTokenCount(string: text) ?? 0
                }
            ).build(
                for: chatModel,
                settings: runtimeConnectionSettings,
                userPersona: userPersona,
                continueResponse: continued,
                forceThinking: runtimeConnectionSettings.forceThinking,
                includeTemplate: continued == false
            )

            let promptBuilder = KoboldRequestBuilder(
                prompt: promptContext.prompt,
                memory: promptContext.memory,
                maxContextLength: runtimeConnectionSettings.contextLength ?? 4096,
                maxLength: runtimeConnectionSettings.responseLength ?? 240,
                temperature: runtimeConnectionSettings.temperature,
                tfs: runtimeConnectionSettings.tfs,
                topA: runtimeConnectionSettings.topA,
                topK: runtimeConnectionSettings.topK,
                topP: runtimeConnectionSettings.topP,
                minP: runtimeConnectionSettings.minP,
                typical: Int(runtimeConnectionSettings.typicalP),
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                repetitionRange: runtimeConnectionSettings.repetitionRange,
                repetitionSlope: runtimeConnectionSettings.repetitionSlope,
                stopSequence: stopSequences,
                samplerOrder: runtimeConnectionSettings.samplerOrder,
                promptTemplate: promptContext.template
            )
            
            serviceResponse = await koboldManager?.sendMessage(builder: promptBuilder)
        case .OpenRouter:
            let promptBuilder = OpenRouterRequestBuilder(
                model: self.selectedModel ?? "deepseek/deepseek-chat-v3-0324:free",
                messages: requestMessages,
                stop: stopSequences,
                temperature: runtimeConnectionSettings.temperature,
                topP: runtimeConnectionSettings.topP,
                minP: runtimeConnectionSettings.minP,
                topA: runtimeConnectionSettings.topA,
                topK: runtimeConnectionSettings.topK,
                maxTokens: runtimeConnectionSettings.responseLength ?? 240,
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                stream: false,
                systemPromptTemplate: runtimeConnectionSettings.userTemplates.values.filter { $0.isEnabled }.map { $0.content }.joined(separator: "\n"),
                characterDescription: chatModel.characterCards.first?.description?.replaceChatSequences(
                    user: userPersona?.name,
                    char: chatModel.chatTitle
                ),
                characterPersonality: chatModel.characterCards.first?.personality?.replaceChatSequences(
                    user: userPersona?.name,
                    char: chatModel.chatTitle
                ),
                characterScenario: chatModel.characterCards.first?.scenario?.replaceChatSequences(
                    user: userPersona?.name,
                    char: chatModel.chatTitle
                )
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
        var normalizedSettings = newConnectionSettings
        normalizedSettings.ensureNonEmptySequences()

        if normalizedSettings.host != runtimeConnectionSettings.host ||
            normalizedSettings.port != runtimeConnectionSettings.port ||
            normalizedSettings.apiKey != runtimeConnectionSettings.apiKey ||
            normalizedSettings.selectedModel != runtimeConnectionSettings.selectedModel ||
            normalizedSettings.connectionType != runtimeConnectionSettings.connectionType {
            self.runtimeConnectionSettings = normalizedSettings
            setupManagers()
        } else {
            self.runtimeConnectionSettings = normalizedSettings
        }
    } 

    private var stopSequences: [String] {
        [
            runtimeConnectionSettings.userStopSequence,
            runtimeConnectionSettings.botStopSequence,
            runtimeConnectionSettings.systemStopSequence
        ]
        .filter { $0.isEmpty == false }
    }

    private var defaultRolePlayPrompt: String {
        TemplatePrompts().defaultRolePlayPrompt(
            thinkingStartSequence: runtimeConnectionSettings.thinkingStartSequence,
            thinkingStopSequence: runtimeConnectionSettings.thinkingStopSequence
        )
    }

    // MARK: - Kobold Functions
    func getMaxContextLength() async -> Int? {
        guard let manager = koboldManager, runtimeConnectionSettings.connectionType == .KoboldAPI else {
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
        guard let manager = koboldManager, runtimeConnectionSettings.connectionType == .KoboldAPI else {
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
        guard let manager = openRouterManager, runtimeConnectionSettings.connectionType == .OpenRouter else {
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
