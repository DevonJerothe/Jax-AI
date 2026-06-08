import Foundation
import SwiftLLMSDK
import SwiftTiktoken

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
    private let loreBookStore: LoreBookStore
    private let personaStore: PersonaStore
    private var hasBootstrappedStores = false
    var tokenizer: CoreBPE?

    var isLoading: Bool {
        connectionStatusManager.connectionStatus == .connecting
    }

    var isConnected: Bool {
        connectionStatusManager.connectionStatus == .connected
    }

    var maxContextLength: Int? {
        connectionStatusManager.maxContextLength
    }

    var selectedConnectionType: APITypeSelection {
        connectionStatusManager.connectionSettings.connectionType
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

    var currentTheme: AppTheme {
        connectionStatusManager.connectionSettings.currentTheme
    }

    var getPersonaName: String {
        personaStore.activePersona?.name ?? "User"
    }

    var getPersonaDescription: String? {
        personaStore.activePersona?.description
    }

    var getPersona: UserPersonaModel? {
        personaStore.activePersona
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
        self.loreBookStore = LoreBookStore(
            loreBookRepository: LoreBookRepository()
        )
        self.personaStore = PersonaStore(
            personaRepository: UserPersonaRepository()
        )

        connectionStatusManager.attachLanguageModelService(languageModelService)

        // if auto connect is enabled, connect to the last used service
        if connectionStatusManager.connectionSettings.autoConnect {
            Task {
                await connectionStatusManager.connect()
            }
        }

        Task {
            self.tokenizer = try? await CoreBPE.cl100kBase()
        }
    }

    func getChatStore() -> ChatStore {
        return self.chatStore
    }

    func getPersonaStore() -> PersonaStore {
        return self.personaStore
    }

    func getCharacterStore() -> CharacterStore {
        return self.characterStore
    }

    func getLoreBookStore() -> LoreBookStore {
        return self.loreBookStore
    }

    func getConnectionStatusManager() -> ConnectionStatusManager {
        connectionStatusManager
    }

    func getLanguageModelService() -> LanguageModelService {
        return self.languageModelService
    }

    func lockForAppResumeIfNeeded() {
        connectionStatusManager.lockForAppResumeIfNeeded()
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

        Task {
            await loreBookStore.startObserving()
        }
    }
}
