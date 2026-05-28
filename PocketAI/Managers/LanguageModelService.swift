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
    var contextBuilder: ContextManager?

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
        guard let host = runtimeConnectionSettings.host, let port = runtimeConnectionSettings.port
        else {
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

    func initContextManager(
        chatModel: ChatModel
    ) async {
        let manager = ContextManager(
            from: chatModel,
            runtimeConnectionSettings
        )
        await manager.prepare()
        self.contextBuilder = manager
    }

    func sendStreamedMessage(
        chatModel: ChatModel,
        userPersona: UserPersonaModel?,
        continued: Bool = false,
        // trimmedPrompt: String
    ) async -> AsyncStream<ModelResponse> {

        guard let contextBuilder else { 
            fatalError("ContextBuilder is not initialized")
        }

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
                maxTokens: runtimeConnectionSettings.responseLength ?? 240,
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                stream: true
            )

            streamResponse = openRouterManager.streamMessage(builder: promptBuilder)
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
        guard let contextBuilder else { 
            fatalError("ContextBuilder is not initialized")
        }

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
                maxTokens: runtimeConnectionSettings.responseLength ?? 240,
                repetitionPenalty: runtimeConnectionSettings.repetitionPenalty,
                stream: false
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

        if normalizedSettings.host != runtimeConnectionSettings.host
            || normalizedSettings.port != runtimeConnectionSettings.port
            || normalizedSettings.apiKey != runtimeConnectionSettings.apiKey
            || normalizedSettings.selectedModel != runtimeConnectionSettings.selectedModel
            || normalizedSettings.connectionType != runtimeConnectionSettings.connectionType
        {
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

    // MARK: - OpenRouter Functions
    func getAvailableModels() async {
        guard let manager = openRouterManager,
            runtimeConnectionSettings.connectionType == .OpenRouter
        else {
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
