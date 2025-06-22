//
//  ChatViewModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import Foundation
import SwiftUI
import SwiftLLMSDK

@Observable
class ChatViewModel: Hashable {
    var id: UUID = UUID()

    private var languageModelService: LanguageModelService? 
    private let messageRepository: MessageRepository
    private let chatRepository: ChatRepository
    private let characterRepository: CharacterRepository

    var model: ChatModel
    var connectionSettings: ConnectionSettingsModel
    var isConnected: Bool {
        return serviceContainer.isConnected
    }

    var updateScrollView: Bool = false
    var showSettings: Bool = false
    var selectionModeActive: Bool = false
    var selectedMessages: Set<MessageModel> = []
    var serviceContainer: ServiceContainer = ServiceContainer.shared

    // MARK: - Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatViewModel, rhs: ChatViewModel) -> Bool {
        return lhs.id == rhs.id
    }

    init(
        chatModel: ChatModel,
        languageModelService: LanguageModelService? = ServiceContainer.shared.getLanguageModelService(),
        messageRepository: MessageRepository = ServiceContainer.shared.getMessageRepository(),
        chatRepository: ChatRepository = ServiceContainer.shared.getChatRepository(),
        characterRepository: CharacterRepository = ServiceContainer.shared.getCharacterRepository()
    ) {
        self.model = chatModel
        self.languageModelService = languageModelService
        self.messageRepository = messageRepository
        self.chatRepository = chatRepository
        self.connectionSettings = ServiceContainer.shared.connectionSettings
        self.characterRepository = characterRepository
    }

    static func create(
        chatModel: ChatModel
    ) -> ChatViewModel {
        return ChatViewModel(
            chatModel: chatModel,
            languageModelService: ServiceContainer.shared.getLanguageModelService()
        )
    }

    func checkConnection() {
        if languageModelService == nil {
            self.languageModelService = ServiceContainer.shared.getLanguageModelService()
        }
    }

    func sendMessage(prompt: String) async {
        await MainActor.run {
            if !prompt.isEmpty {
                self.model.addMessage(prompt, forActor: .user)
                try! messageRepository.save(self.model.messages.last!)
            }
            self.model.addMessage(forActor: .bot, isLoading: true)
            self.updateScrollView.toggle()
        }
        await generateResponse(model.messages.count - 1)
    }

    func regenerateMessage(_ message: MessageModel, continueResponse: Bool = false) async {
        let lastIndex = self.model.messages.count - 1
        await MainActor.run {
            self.model.messages[lastIndex].loading = true
            self.updateScrollView.toggle()
        }
        await generateResponse(lastIndex, isContinued: continueResponse)
    }

    func clearChat() {
        self.model.resetChat()
        try! chatRepository.save(self.model)
        
        // Post notification that chat data has changed
        NotificationCenter.default.post(name: .chatDataChanged, object: self.model)
    }


    func updateChatSettings(
        characterCard: CharacterCardModel
    ) {
        model.updateCard(characterCard)
        try! chatRepository.save(self.model)

        // update the connection settings
        serviceContainer.saveConnectionSettings()

        // Post notification that chat data has changed
        NotificationCenter.default.post(name: .chatDataChanged, object: self.model)
    }

    func updateMessage(_ message: MessageModel, newText: String) async {
        let lastIndex = self.model.messages.count - 1
        await MainActor.run {
            self.model.messages[lastIndex].text = newText
        }
        try! messageRepository.save(self.model.messages[lastIndex])
        
        // Post notification that chat data has changed
        await MainActor.run {
            NotificationCenter.default.post(name: .chatDataChanged, object: self.model)
        }
    }

    func toggleSelection(_ message: MessageModel) {
        if selectedMessages.contains(message) {
            selectedMessages.remove(message)
        } else {
            selectedMessages.insert(message)
        }
    }

    func deleteMessages() async {
        await MainActor.run {
            self.model.messages.removeAll(where: { self.selectedMessages.contains($0) })
            selectedMessages.removeAll()
            selectionModeActive = false
        }
        try! chatRepository.save(self.model)
        
        // Post notification that chat data has changed
        await MainActor.run {
            NotificationCenter.default.post(name: .chatDataChanged, object: self.model)
        }
    }
    
    func deleteMessage(_ message: MessageModel) async {
        print("ChatViewModel: Starting deleteMessage for message ID: \(message.id.uuidString)")
        print("ChatViewModel: Current message count before delete: \(self.model.messages.count)")
        
        await MainActor.run {
            self.model.messages.removeAll(where: { message == $0 })
            print("ChatViewModel: Message count after in-memory delete: \(self.model.messages.count)")
        }
        
        do {
            try chatRepository.save(self.model)
            print("ChatViewModel: Successfully saved chat to database after delete")
        } catch {
            print("ChatViewModel: ERROR saving chat after delete: \(error)")
        }
        
        // Post notification that chat data has changed
        await MainActor.run {
            NotificationCenter.default.post(name: .chatDataChanged, object: self.model)
            print("ChatViewModel: Posted chatDataChanged notification")
        }
    }

    func shouldShowToolbar(_ message: MessageModel) -> Bool {
        if model.messages.count > 1, model.messages.last?.id == message.id {
            return true
        }
        return false
    }

    private func isBelowContextLimit() -> Bool {
        return true
    }

    private func generateResponse(_ forIndex: Int, isContinued: Bool = false) async {
        
        guard let languageModelService = languageModelService else {
            print("service not loaded")
            return
        }
        
        // TODO: Go fix the RequestBodyBuilder
        // right now if no response is returned or the API returns an error we return nil. Not sure I like this.
        let response = await languageModelService.sendMessage(chatModel: self.model, continued: isContinued)
        guard let responseMessage = response?.text else{
            print("No response check logs")
            return
        }
        
        await MainActor.run {
            if isContinued {
                self.model.messages[forIndex].text.append(responseMessage)
            } else {
                self.model.messages[forIndex].text = responseMessage
            }
            self.model.messages[forIndex].loading = false
            
            do {
                try messageRepository.save(self.model.messages[forIndex])
            } catch(let error) {
                print("ERROR: \(error.localizedDescription)")
            }
            self.updateScrollView.toggle()
            
            // Post notification that chat data has changed
            NotificationCenter.default.post(name: .chatDataChanged, object: self.model)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chatDataChanged = Notification.Name("chatDataChanged")
}
