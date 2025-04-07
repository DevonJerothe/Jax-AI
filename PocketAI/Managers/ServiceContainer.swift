import Foundation
import SwiftLLMSDK

///
/// This service container is responsible for all dependency injection and shared services such as userDefaults and connection status
///
@Observable
class ServiceContainer {

    static let shared = ServiceContainer() 

    // MARK: - Connection Settings
    var connectionSettings: ConnectionSettingsModel = .defaults
    var modelName: String?
    var isConnected: Bool = false

    private var languageModelService: LanguageModelService?
    private var databaseManager: DBManager?
    private var userDefaultsManager: UserDefaultsManager = UserDefaultsManager.shared

    private var messageRepository: MessageRepository = MessageRepository()
    private var chatRepository: ChatRepository = ChatRepository()
    private var characterRepository: CharacterRepository = CharacterRepository()

    private init() {
        // Load Connection Settings if any exist
        if let connectionSettings = self.userDefaultsManager.fetchConnectionSettiongs() {
            self.connectionSettings = connectionSettings
        }
    }

    func connectToLanguageModel() async -> Bool {
        // TODO: Support multiple language models
        guard let host = connectionSettings.host, let port = connectionSettings.port else {
            return false
        }
        self.languageModelService = KoboldAPI(urlSession: URLSession.shared, host: host, port: port)

        let llmName = await self.languageModelService?.getModel()
        switch llmName {
            case .success(let name):
                self.modelName = name
                self.isConnected = true
                return true
            case .failure(let error):
                print("Error: \(error)")
            case .none:
                print("Error: No model name")
        }
        return false
    }
    
    func getLanguageModelService() -> LanguageModelService? {
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
        self.userDefaultsManager.saveSettings(self.connectionSettings, forKey: .ConnectionSettings)
    }
}
