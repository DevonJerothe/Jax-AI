import Foundation
import SwiftLLMSDK

///
/// This service container is responsible for all dependency injection and shared services such as userDefaults and connection status
///
@MainActor
@Observable
final class ServiceContainer {

    static let shared = ServiceContainer()

    private let languageModelService: LanguageModelService
    private let connectionStatusManager: ConnectionStatusManager
    private let chatStore: ChatStore
    private let characterStore: CharacterStore
    private var hasBootstrappedStores = false
    
    var isLoading: Bool {
        connectionStatusManager.connectionStatus == .connecting
    }

    var isConnected: Bool {
        connectionStatusManager.connectionStatus == .connected
    }

    var maxContextLength: Int? {
        connectionStatusManager.maxContextLength
    }
    
    var selectedModelName: String? {
        self.languageModelService.selectedModel
    }
    
    var availableModels: [OpenRouterModel] {
        self.languageModelService.availableModels
    }

    var isLoadingConnection: Bool {
        isLoading
    }

    private init() {
        self.connectionStatusManager = ConnectionStatusManager()
        self.languageModelService = LanguageModelService(
            initialConnectionSettings: connectionStatusManager.connectionSettings
        )
        self.chatStore = ChatStore(
            chatRepository: ChatRepository(),
            messageRepository: MessageRepository()
        )
        self.characterStore = CharacterStore(
            characterRepository: CharacterRepository()
        )

        connectionStatusManager.attachLanguageModelService(languageModelService)
    }
    
    func getChatStore() -> ChatStore {
        return self.chatStore
    }
    
    func getCharacterStore() -> CharacterStore {
        return self.characterStore
    }

    func getConnectionStatusManager() -> ConnectionStatusManager {
        connectionStatusManager
    }

    func getLanguageModelService() -> LanguageModelService {
        return self.languageModelService
    }

    /// Starts the shared DB observers once so every screen can read from the same
    /// in-memory source of truth.
    func bootstrap() {
        guard hasBootstrappedStores == false else {
            return
        }

        hasBootstrappedStores = true

        Task {
            await chatStore.startObserving()
        }

        Task {
            await characterStore.startObserving()
        }
    }
}
