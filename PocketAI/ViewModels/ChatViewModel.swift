//
//  ChatViewModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import Foundation
import SwiftUI
import SwiftLLMSDK
import UIKit

@Observable
class ChatViewModel: Hashable {
    var id: UUID = UUID()

    private var languageModelService: LanguageModelService 
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
    var isStreaming: Bool = false {
        didSet {
            self.model.isStreaming = self.isStreaming
            self.model.isLoading = self.isStreaming
            triggerChatUpdate()
        }
    }
    var isThinking: Bool = false {
        didSet {
            self.model.isThinking = self.isThinking
            triggerChatUpdate()
        }
    }
    var serviceContainer: ServiceContainer = ServiceContainer.shared
    var editingMessageID: UUID?
    private var lastHapticTriggerAt: Date? = nil
    var newInstance: Bool = true
    var isViewActive: Bool = false
    var chatListViewModel: ChatListViewModel? 

    // MARK: - Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatViewModel, rhs: ChatViewModel) -> Bool {
        return lhs.id == rhs.id
    }

    init(
        chatModel: ChatModel,
        languageModelService: LanguageModelService = ServiceContainer.shared.getLanguageModelService(),
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

        // update booleans based on the chat model 
        self.isStreaming = self.model.isStreaming
        self.isThinking = self.model.isThinking
    }

    static func create(
        chatModel: ChatModel
    ) -> ChatViewModel {
        return ChatViewModel(
            chatModel: chatModel,
            languageModelService: ServiceContainer.shared.getLanguageModelService()
        )
    }

    /// trigger the chatListViewModel to refresh all data 
    private func triggerListRefresh() {
        Task {
            await MainActor.run {
                chatListViewModel?.refreshData()
            }
        }
    }

    /// Trigger the ChatListViewModel to update the chat in the list. This will allow us to update list items based on chat status changes. 
    private func triggerChatUpdate() {
        Task {
            await MainActor.run {
                chatListViewModel?.updateChatInList(model)
            }
        }
    }

    func updateChatLoadingStatus(model: ChatModel) {
        Task {
            await MainActor.run {
                self.model = model 
                self.isStreaming = self.model.isStreaming
                self.isThinking = self.model.isThinking
                self.updateScrollView.toggle()
            }
        }
    }

    func sendMessage(prompt: String) async {
        await MainActor.run {
            self.newInstance = false
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
            self.newInstance = false
            self.model.messages[lastIndex].loading = true
            self.updateScrollView.toggle()
        }
        await generateResponse(lastIndex, isContinued: continueResponse)
    }

    func clearChat() {
        self.model.resetChat()
        try! chatRepository.save(self.model)
        
        triggerListRefresh()
    }

    func updateChatSettings(
        characterCard: CharacterCardModel
    ) {
        model.updateCard(characterCard)
        try! chatRepository.save(self.model)

        // update the connection settings
        serviceContainer.saveConnectionSettings()

        triggerListRefresh()
    }

    func updateMessage(_ message: MessageModel, newText: String) async {
        let lastIndex = self.model.messages.count - 1
        await MainActor.run {
            self.newInstance = false
            self.model.messages[lastIndex].text = newText
        }
        try! messageRepository.save(self.model.messages[lastIndex])

        triggerListRefresh()
    }
    
    func deleteMessage(_ message: MessageModel) async {
        await MainActor.run {
            self.newInstance = false
            self.model.messages.removeAll(where: { message == $0 })
        }
        try! chatRepository.save(self.model)
        
        triggerListRefresh()
    }

    func shouldShowToolbar(_ message: MessageModel) -> Bool {
        if model.messages.count > 1, model.messages.last?.id == message.id, isStreaming == false {
            return true
        }
        return false
    }
    
    private func generateStreamedResponse(_ forIndex: Int, isContinued: Bool = false, excludeThinking: Bool = true, trimmedPrompt: String) {
        // Update the connection settings if necessary
        languageModelService.updateConnection()
        
        guard languageModelService.isConnected else {
            print("Language Model Service is not connected")
            Task {  
                await MainActor.run {
                    self.model.messages[forIndex].error = .disconnect
                    self.model.messages[forIndex].loading = false
                    self.model.messages[forIndex].text = "Looks like you're not connected to a model. Please check your connection settings."
                    try! messageRepository.save(self.model.messages[forIndex])
                    triggerListRefresh()
                    self.updateScrollView.toggle()
                }
            }
            return
        }
        
        Task {
            let stream = languageModelService.sendStreamedMessage(chatModel: self.model, continued: isContinued, trimmedPrompt: trimmedPrompt)
            self.isStreaming = true
            
            for await response in stream {

                // Depending on models, kobold sometimes(most of the time) sucks at including the <think> tag at the start.
                // To check, we want to find the first non-whitespace character and see if it's '<'.
                // This way we can stream the response without waiting if not excludeing thinking.. 
                let firstNonWhitespaceChar = response.text?.first(where: { !$0.isWhitespace })
                let didThinkingStart = firstNonWhitespaceChar == "<"
                let didThinkingFinish = (response.text?.contains("</think>")) ?? false || isContinued

                if didThinkingStart && !didThinkingFinish {
                    self.isThinking = true
                } else {
                    self.isThinking = false
                }

                await MainActor.run {
                    if response.disconnect {
                        self.model.messages[forIndex].error = .apiError
                        self.model.messages[forIndex].text = response.text ?? ""
                        self.model.messages[forIndex].loading = false
                        self.updateScrollView.toggle()

                        do {
                            try messageRepository.save(self.model.messages[forIndex])
                            // Post notification that chat data has changed
                            triggerListRefresh()
                        } catch {
                            print("ERROR: \(error.localizedDescription)")
                        }
                        return
                    }

                    // Remove everything from the beginning of the string up to and including the first </think> tag.
                    // The opening <think> tag may or may not be present; we only rely on the closing tag.
                    if !excludeThinking || didThinkingFinish || !didThinkingStart {
                        let responseMessage = response.text ?? ""
                        let sanitizedResponse = responseMessage
                            .replacing(/\A[\s\S]*?<\/think>\s*/, with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        self.model.messages[forIndex].loading = false
                        
                        self.model.messages[forIndex].text = sanitizedResponse

                        self.updateScrollView.toggle()

                        do {
                            if response.streaming == false {
                                print("STREAMING FINISHED SUCCESSFULLY")
                                self.isStreaming = false
                                try messageRepository.save(self.model.messages[forIndex])
                                triggerListRefresh()
                            }
                        } catch (let error) {
                            print("ERROR: \(error.localizedDescription)")
                        }

                        // Hatpic debouncer so that we are  not spamming the user. 
                        // also check if the view is active or not.. this should stop haptics when user navigates away before response is finished.
                        let now = Date()
                        if self.isViewActive && (self.lastHapticTriggerAt == nil || now.timeIntervalSince(self.lastHapticTriggerAt!) >= 0.1) {
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.impactOccurred()
                            self.lastHapticTriggerAt = now
                        }
                    }
                    
                    // Sometimes the stream can break.. or thinking doesn't provide a closing tag. 
                    // This should be checked later.. we may not need it now that we are checking if streaming starts and ends up top. 
                    if response.streaming == false, self.isStreaming {
                        print("STREAMING FAILED")
                        self.model.messages[forIndex].loading = false
                        self.isStreaming = false
                        self.model.messages[forIndex].text = response.text ?? ""
                        
                        do {
                            try messageRepository.save(self.model.messages[forIndex])
                            // Post notification that chat data has changed
                            triggerListRefresh()
                            self.updateScrollView.toggle()

                        } catch {
                            print("ERROR: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func generateResponse(_ forIndex: Int, isContinued: Bool = false, streamed: Bool = true) async {
        // Update the connection settings if necessary
        languageModelService.updateConnection()
        
        guard languageModelService.isConnected else {
            print("Language Model Service is not connected")
            self.model.messages[forIndex].error = .disconnect
            self.model.messages[forIndex].loading = false
            self.model.messages[forIndex].text = "Looks like you're not connected to a model. Please check your connection settings."
            try! messageRepository.save(self.model.messages[forIndex])
            triggerListRefresh()
            self.updateScrollView.toggle()

            return
        }
        
        if streamed {
            ///TODO: once thinking becomes a settings we need to handle this cleanly.
            ///Right now only kobold needs to filter out the thinking manually. OpenRouter does this at the API level.
            //Also auto trimmed prompts require await.. so have to do it here. We really need to keep tokens on the message model.
            let excludeThinking: Bool = connectionSettings.connectionType == .KoboldAPI
            let trimmedPrompt = await model.autoTrimFullPrompt(continueResponse: isContinued)
            return generateStreamedResponse(forIndex, isContinued: isContinued, excludeThinking: excludeThinking, trimmedPrompt: trimmedPrompt)
        }
        
        // right now if no response is returned or the API returns an error we return nil. Not sure I like this.
        let response = await languageModelService.sendMessage(chatModel: self.model, continued: isContinued)
        guard let responseMessage = response?.text else{
            print("No response check logs")
            await MainActor.run {
                self.model.messages[forIndex].loading = false
                self.model.messages[forIndex].error = .apiError
                self.model.messages[forIndex].text = "There was an error processing your request. Please try again later."
            }
            return
        }

        // Remove everything from the beginning of the string up to and including the first </think> tag.
        // The opening <think> tag may or may not be present; we only rely on the closing tag.
        let sanitizedResponse = responseMessage
            .replacing(/\A[\s\S]*?<\/think>\s*/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            if response?.disconnect ?? false {
                self.model.messages[forIndex].error = .apiError
                self.model.messages[forIndex].text = sanitizedResponse
            } else {
                if isContinued {
                    self.model.messages[forIndex].text.append(sanitizedResponse)
                } else {
                    self.model.messages[forIndex].text = sanitizedResponse
                }
            }

            self.model.messages[forIndex].loading = false
            
            do {
                try messageRepository.save(self.model.messages[forIndex])
            } catch(let error) {
                print("ERROR: \(error.localizedDescription)")
            }
            self.updateScrollView.toggle()
            
            triggerChatUpdate()
        }
    }
}