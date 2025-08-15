import Foundation
import SwiftLLMSDK

///
/// This service container is responsible for all dependency injection and shared services such as userDefaults and connection status
///
@Observable
class ServiceContainer {

    static let shared = ServiceContainer()

    var connectionSettings: ConnectionSettingsModel = .defaults
    var isLoading: Bool = false

    private var languageModelService: LanguageModelService
    private var databaseManager: DBManager?
    private var userDefaultsManager: UserDefaultsManager = UserDefaultsManager
        .shared

    private var messageRepository: MessageRepository = MessageRepository()
    private var chatRepository: ChatRepository = ChatRepository()
    private var characterRepository: CharacterRepository = CharacterRepository()
    
    // MARK: - Computed Properties
    var isConnected: Bool {
        self.languageModelService.isConnected
    }

    var maxContextLength: Int? {
        self.languageModelService.maxContextLength
    }
    
    var selectedModelName: String? {
        self.languageModelService.selectedModel
    }
    
    var availableModels: [OpenRouterModel] {
        self.languageModelService.availableModels
    }

    var isLoadingConnection: Bool {
        self.languageModelService.isLoadingConnection
    }

    private init() {
        // Load Connection Settings if any exist
        if let savedConnectionSettings = UserDefaultsManager.shared.fetchConnectionSettiongs() {
            self.connectionSettings = savedConnectionSettings
            self.languageModelService = LanguageModelService(connectionSettings: savedConnectionSettings)
        } else {
            self.languageModelService = LanguageModelService(connectionSettings: .defaults)
        }
    }

    func getLanguageModelService() -> LanguageModelService {
        return self.languageModelService
    }

    func getMessageRepository() -> MessageRepository {
        return self.messageRepository
    }

    func getChatRepository() -> ChatRepository {
        return self.chatRepository
    }

    func getCharacterRepository() -> CharacterRepository {
        return self.characterRepository
    }

    func saveConnectionSettings() {
        self.userDefaultsManager.saveSettings(
            self.connectionSettings, forKey: .ConnectionSettings)
        self.languageModelService.updateConnection()
    }
    
    // MARK: - LanguageModelService Helpers
    // Its better to call the language service methods directly than here.
    func connect() async {
        self.languageModelService.updateConnection()
        self.isLoading = true
        await _ = self.languageModelService.connect()

        if self.connectionSettings.contextLength ?? 0 > self.languageModelService.maxContextLength {
            self.connectionSettings.contextLength = self.languageModelService.maxContextLength
        }
        self.saveConnectionSettings()
        self.isLoading = false
    }

    func waitForConnection() async -> Bool {
        self.saveConnectionSettings()
        self.isLoading = true
        let connectionStatus = await self.languageModelService.connect()
        self.isLoading = false
        return connectionStatus
    }

    func getAvailableModels() async {
        await self.languageModelService.getAvailableModels()
    }
}
