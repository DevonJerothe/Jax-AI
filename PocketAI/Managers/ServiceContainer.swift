import Foundation
import SwiftLLMSDK

@Observable
class ServiceContainer {

    static let shared = ServiceContainer() 

    // MARK: - Connection Settings
    var host: String? 
    var port: Int? 
    var contextLength: Int?
    var tokenResponseLength: Int?
    var modelName: String?
    var isConnected: Bool = false

    private var languageModelService: LanguageModelService?
    private var databaseManager: DBManager?

    private var messageRepository: MessageRepository = MessageRepository()
    private var chatRepository: ChatRepository = ChatRepository()

    private(set) var lastHost: String?
    private(set) var lastPort: Int?

    private init() {}

    func connectToLanguageModel(host: String, port: Int) async -> Bool {
        // TODO: Support multiple language models
        self.languageModelService = KoboldAPI(urlSession: URLSession.shared, host: host, port: port)
        self.lastHost = host
        self.lastPort = port

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

    func reconnect() async -> Bool{
        guard let host = lastHost, let port = lastPort else {
            return false
        }
        return await connectToLanguageModel(host: host, port: port)
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
}
