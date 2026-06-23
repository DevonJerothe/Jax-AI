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
    var openAICustom: APIManager<OpenAPI>?
    var contextBuilder: ContextManager?

    var selectedModel: String?
    var availableModels: [OpenRouterModel] = []
    var availableOpenAIModels: [OpenAIModel] = []
    var maxContextLength: Int = 26000

    init(initialConnectionSettings: ConnectionSettingsModel) {
        var normalizedSettings = initialConnectionSettings
        normalizedSettings.ensureNonEmptySequences()
        self.runtimeConnectionSettings = normalizedSettings

        setupManagers()
    }

    private func setupManagers() {
        if let host = runtimeConnectionSettings.activeHost,
           let port = runtimeConnectionSettings.activePort {
            self.koboldManager = .init(
                forService: KoboldAPI(
                    urlSession: URLSession.shared,
                    host: host,
                    port: port
                )
            )
        } else {
            self.koboldManager = nil
        }

        let openAISettings = runtimeConnectionSettings.openAISettings
        self.openAICustom = .init(
            forService: OpenAPI(
                urlSession: URLSession.shared,
                baseURL: openAISettings?.baseURL ?? "",
                selectedModel: openAISettings?.selectedModel ?? "",
                apiKey: openAISettings?.apiKey
            )
        )
       
        self.openRouterManager = .init(
            forService: OpenRouterAPI(
                urlSession: URLSession.shared,
                selectedModel: runtimeConnectionSettings.openRouterSettings?.selectedModel,
                apiKey: runtimeConnectionSettings.openRouterSettings?.apiKey
            )
        )

        if runtimeConnectionSettings.connectionType == .OpenRouter || runtimeConnectionSettings.connectionType == .OpenAI {
            self.selectedModel = runtimeConnectionSettings.activeSelectedModel
        }
    }

    private func contextManager(for chatModel: ChatModel) async -> ContextManager {
        // Ensure both the context manager is active, and contains the current chat
        if let contextBuilder, contextBuilder.chat.id == chatModel.id {
            contextBuilder.syncSettigns(runtimeConnectionSettings)
            return contextBuilder
        }

        let manager = ContextManager(
            from: chatModel,
            runtimeConnectionSettings
        )
        await manager.prepare()
        self.contextBuilder = manager
        return manager
    }
    
    func connect() async -> Bool {
        print("Connecting to \(runtimeConnectionSettings.connectionType)")
        print("Current Context Length: \(runtimeConnectionSettings.activeContextLength ?? 0)")
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
        case .OpenAI: 
            let result = await openAICustom?.connect()
            switch result {
            case .success(let model): 
                self.selectedModel = model
                return true
            case .failure(let error):
                print("ERROR: \(error)")
            case .none: 
                print("ERROR: Unexpected Error")
            }
        }
        return false
    }

    func disconnect() {
        selectedModel = nil
    }

    func initContextManager(
        chatModel: ChatModel
    ) async {
        _ = await contextManager(for: chatModel)
    }

    func sendStreamedMessage(
        chatModel: ChatModel,
        userPersona: UserPersonaModel?,
        continued: Bool = false,
        // trimmedPrompt: String
    ) async -> AsyncStream<ModelResponse> {
        let contextBuilder = await contextManager(for: chatModel)

        let contextResult = await contextBuilder.buildContext(
            chat: chatModel,
            continued: continued,
            forceThinking: runtimeConnectionSettings.forceThinking
        )

        let (stream, continuation) = AsyncStream<ModelResponse>.makeStream()
        var streamResponse: AsyncStream<Result<ModelResponse, APIError>>

        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:
            guard let koboldManager = koboldManager else {
                streamResponse = AsyncStream { continuation in 
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            guard let contextPrompt = contextResult?.textCompletion else {
                streamResponse = AsyncStream { continuation in 
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            let promptBuilder = KoboldRequestBuilder(
                prompt: contextPrompt.prompt,
                memory: contextPrompt.memory,
                maxContextLength: runtimeConnectionSettings.activeContextLength ?? 4096,
                maxLength: runtimeConnectionSettings.activeResponseLength ?? 240,
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
                samplerOrder: runtimeConnectionSettings.samplerOrder
            )

            streamResponse = koboldManager.streamMessage(builder: promptBuilder)
        case .OpenRouter:
            guard let openRouterManager = openRouterManager else {
                streamResponse = AsyncStream { continuation in 
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            guard let contextMessages = contextResult?.chatCompletion else {
                streamResponse = AsyncStream { continuation in 
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            guard let selectedModel = self.selectedModel else {
                streamResponse = AsyncStream { continuation in 
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            let promptBuilder = OpenRouterRequestBuilder(
                model: selectedModel,
                messages: contextMessages.messages,
                stop: stopSequences,
                temperature: runtimeConnectionSettings.temperature,
                topP: runtimeConnectionSettings.topP,
                minP: runtimeConnectionSettings.minP,
                topA: runtimeConnectionSettings.topA,
                topK: runtimeConnectionSettings.topK,
                maxTokens: runtimeConnectionSettings.activeResponseLength ?? 240,
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                stream: true
            )

            streamResponse = openRouterManager.streamMessage(builder: promptBuilder)
        case .OpenAI:
            guard let openAICustom = openAICustom else {
                streamResponse = AsyncStream { continuation in
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            guard let contextMessages = contextResult?.chatCompletion else {
                streamResponse = AsyncStream { continuation in
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            guard let selectedModel = runtimeConnectionSettings.activeSelectedModel else {
                streamResponse = AsyncStream { continuation in
                    continuation.yield(.failure(.invalidService))
                    continuation.finish()
                }
                break
            }

            let promptBuilder = ChatCompletionRequestBuilder(
                model: selectedModel,
                messages: contextMessages.messages,
                stop: stopSequences,
                temperature: runtimeConnectionSettings.temperature,
                topP: runtimeConnectionSettings.topP,
                maxTokens: runtimeConnectionSettings.activeResponseLength ?? 240,
                stream: true
            )

            streamResponse = openAICustom.streamMessage(builder: promptBuilder)
        }
        Task(priority: .medium) {
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
        let contextBuilder = await contextManager(for: chatModel)

        let contextResult = await contextBuilder.buildContext(
            chat: chatModel,
            continued: continued,
            forceThinking: runtimeConnectionSettings.forceThinking
        )

        var serviceResponse: Result<ModelResponse, APIError>?

        switch runtimeConnectionSettings.connectionType {
        case .KoboldAPI:

            guard let contextPrompt = contextResult?.textCompletion else {
                fatalError("No Context")
            }

            let promptBuilder = KoboldRequestBuilder(
                prompt: contextPrompt.prompt,
                memory: contextPrompt.memory,
                maxContextLength: runtimeConnectionSettings.activeContextLength ?? 4096,
                maxLength: runtimeConnectionSettings.activeResponseLength ?? 240,
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
            )

            serviceResponse = await koboldManager?.sendMessage(builder: promptBuilder)
        case .OpenRouter:
            guard let contextMessages = contextResult?.chatCompletion else {
                fatalError("No Context")
            }

            guard let selectedModel = self.selectedModel else {
                return ModelResponse(
                    role: "assistant", 
                    text: "Model not selected or available", 
                    disconnect: true
                )
            }
        
            let promptBuilder = OpenRouterRequestBuilder(
                model: selectedModel,
                messages: contextMessages.messages,
                stop: stopSequences,
                temperature: runtimeConnectionSettings.temperature,
                topP: runtimeConnectionSettings.topP,
                minP: runtimeConnectionSettings.minP,
                topA: runtimeConnectionSettings.topA,
                topK: runtimeConnectionSettings.topK,
                maxTokens: runtimeConnectionSettings.activeResponseLength ?? 240,
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                stream: false
            )

            serviceResponse = await openRouterManager?.sendMessage(builder: promptBuilder)
        case .OpenAI:
            guard let contextMessages = contextResult?.chatCompletion else {
                fatalError("No Context")
            }

            guard let selectedModel = runtimeConnectionSettings.activeSelectedModel else {
                return ModelResponse(
                    role: "assistant",
                    text: "Model not selected or available",
                    disconnect: true
                )
            }

            let promptBuilder = ChatCompletionRequestBuilder(
                model: selectedModel,
                messages: contextMessages.messages,
                stop: stopSequences,
                temperature: runtimeConnectionSettings.temperature,
                topP: runtimeConnectionSettings.topP,
                maxTokens: runtimeConnectionSettings.activeResponseLength ?? 240,
                stream: false
            )

            serviceResponse = await openAICustom?.sendMessage(builder: promptBuilder)
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

        let shouldRebuildManagers =  normalizedSettings.activeHost != runtimeConnectionSettings.activeHost
            || normalizedSettings.activePort != runtimeConnectionSettings.activePort
            || normalizedSettings.openRouterSettings?.apiKey != runtimeConnectionSettings.openRouterSettings?.apiKey
            || normalizedSettings.openRouterSettings?.selectedModel != runtimeConnectionSettings.openRouterSettings?.selectedModel
            || normalizedSettings.openAISettings?.baseURL != runtimeConnectionSettings.openAISettings?.baseURL
            || normalizedSettings.openAISettings?.apiKey != runtimeConnectionSettings.openAISettings?.apiKey
            || normalizedSettings.openAISettings?.selectedModel != runtimeConnectionSettings.openAISettings?.selectedModel
            || normalizedSettings.connectionType != runtimeConnectionSettings.connectionType
        
        self.runtimeConnectionSettings = normalizedSettings
        contextBuilder?.syncSettigns(normalizedSettings)

        if shouldRebuildManagers {
            setupManagers()         
        }
    }

    private var stopSequences: [String] {
        [
            runtimeConnectionSettings.userStopSequence,
            runtimeConnectionSettings.botStopSequence,
            runtimeConnectionSettings.systemStopSequence,
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
        guard let manager = koboldManager, runtimeConnectionSettings.connectionType == .KoboldAPI
        else {
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
        guard let manager = koboldManager, runtimeConnectionSettings.connectionType == .KoboldAPI
        else {
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

    // MARK: - Chat Completion Functions
    func getAvailableModels() async {
        switch runtimeConnectionSettings.connectionType {
        case .OpenRouter:
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
        case .OpenAI:
            guard let manager = openAICustom else {
                print("No OpenAI Manager")
                return
            }
            let result = await manager.getAvailableModels()
            switch result {
            case .success(let models):
                self.availableOpenAIModels = models
            case .failure(let error):
                print("Error: \(error)")
            }
        case .KoboldAPI:
            return
        }
    }
}
