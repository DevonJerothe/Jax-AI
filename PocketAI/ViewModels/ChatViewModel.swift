//
//  ChatViewModel.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import Foundation
import SwiftLLMSDK
import SwiftUI
import UIKit

@MainActor
@Observable
final class ChatViewModel {
    private let languageModelService: LanguageModelService
    private let connectionManager: ConnectionStatusManager
    private let chatStore: ChatStore
    private let characterStore: CharacterStore

    let chatID: UUID

    var model: ChatModel? {
        chatStore.chat(withID: chatID)
    }

    var shouldHidePrivateContent: Bool {
        connectionManager.connectionSettings.locked && model?.isPrivate == true
    }

    var isConnected: Bool {
        connectionManager.connectionStatus == .connected
    }

    var isStreaming: Bool {
        guard let status = model?.status else {
            return false
        }

        return status == .loading || status == .thinking || status == .streaming
    }

    var isThinking: Bool {
        model?.status == .thinking
    }

    var updateScrollView: Bool = false
    var showSettings: Bool = false
    var editingMessageID: UUID?
    var newInstance: Bool = true
    var isViewActive: Bool = false

    private var lastHapticTriggerAt: Date?

    init(
        chatID: UUID,
        languageModelService: LanguageModelService? = nil,
        connectionManager: ConnectionStatusManager? = nil,
        chatStore: ChatStore? = nil,
        characterStore: CharacterStore? = nil
    ) {
        self.chatID = chatID
        self.languageModelService = languageModelService ?? ServiceContainer.shared.getLanguageModelService()
        self.connectionManager = connectionManager ?? ServiceContainer.shared.getConnectionStatusManager()
        self.chatStore = chatStore ?? ServiceContainer.shared.getChatStore()
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
    }

    func fetchCharacterCard() -> CharacterCardModel? {
        guard let characterID = model?.characterCards.first?.id else {
            return nil
        }

        return characterStore.character(withID: characterID)
    }

    func sendMessage(prompt: String) async {
        guard let chat = model else {
            return
        }

        newInstance = false

        let userMessage = MessageModel(
            chatId: chat.id.uuidString,
            actor: .user,
            text: prompt
        )

        let placeholder = MessageModel(
            chatId: chat.id.uuidString,
            actor: .bot,
            text: "",
            status: .loading
        )

        do {
            if prompt.isEmpty == false {
                try await chatStore.addMessage(userMessage, to: chat.id)
            }
            try await chatStore.addMessage(placeholder, to: chat.id)
            updateScrollView.toggle()
            await generateResponse(for: placeholder.id)
        } catch {
            print("Failed to queue message: \(error)")
        }
    }

    func regenerateMessage(_ message: MessageModel, continueResponse: Bool = false) async {
        guard let chat = model else {
            return
        }

        var updatedMessage = message
        updatedMessage.error = .none
        updatedMessage.status = .loading

        if continueResponse == false {
            updatedMessage.text = ""
        }

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id, save: false)
            updateScrollView.toggle()
            await generateResponse(for: updatedMessage.id, isContinued: continueResponse)
        } catch {
            print("Failed to regenerate message: \(error)")
        }
    }

    func clearChat() async {
        guard var chat = model else {
            return
        }

        chat.messages.removeAll()
        chat.addMessage(chat.characterCards.first?.firstMessage ?? "", forActor: .bot)

        do {
            try await chatStore.saveChat(chat)
        } catch {
            print("Failed to clear chat: \(error)")
        }
    }

    func updateChatSettings(characterCard: CharacterCardModel, isPrivate: Bool) async {
        guard var chat = model else {
            return
        }

        chat.characterCards = [characterCard]
        chat.memory = characterCard.description ?? chat.memory
        chat.isPrivate = isPrivate

        do {
            try await chatStore.saveChat(chat)
        } catch {
            print("Failed to update chat settings: \(error)")
        }
    }

    func updateMessage(_ message: MessageModel, newText: String) async {
        guard let chat = model else {
            return
        }

        var updatedMessage = message
        updatedMessage.text = newText

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id)
        } catch {
            print("Failed to update message: \(error)")
        }
    }

    func deleteMessage(_ message: MessageModel) async {
        guard let chat = model else {
            return
        }

        do {
            try await chatStore.deleteMessage(message, from: chat.id)
        } catch {
            print("Failed to delete message: \(error)")
        }
    }

    func shouldShowToolbar(_ message: MessageModel) -> Bool {
        guard let chat = model else {
            return false
        }

        return chat.messages.count > 1 &&
            chat.messages.last?.id == message.id &&
        chat.status == .idle && message.status == .done
    }

    private func generateResponse(for messageID: UUID, isContinued: Bool = false, streamed: Bool = true) async {
        guard let chat = model,
            let messageIndex = chat.messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        guard isConnected else {
            await finalizeDisconnectedMessage(at: messageIndex, in: chat)
            return
        }

        if streamed {
            let excludeThinking = connectionManager.connectionSettings.connectionType == .KoboldAPI
            let trimmedPrompt = await autoTrimPrompt(
                for: chat,
                continueResponse: isContinued,
                forceThinking: connectionManager.connectionSettings.forceThinking
            )

            generateStreamedResponse(
                for: messageID,
                chat: chat,
                isContinued: isContinued,
                excludeThinking: excludeThinking,
                trimmedPrompt: trimmedPrompt
            )
            return
        }

        let response = await languageModelService.sendMessage(chatModel: chat, continued: isContinued)
        let responseText = response?.text ?? "There was an error processing your request. Please try again later."
        let sanitizedResponse = ReasoningStreamParser.visibleText(from: responseText)
        let originalText = isContinued ? chat.messages[messageIndex].text : ""
        let visibleResponse = StreamAccumulator(
            originalText: originalText,
            continuationSeparator: " "
        ).combinedVisibleText(sanitizedResponse)

        await applyResponseUpdate(
            for: messageID,
            responseText: visibleResponse,
            disconnect: response?.disconnect ?? true,
            isFinal: true,
            shouldShowThinking: false
        )
    }

    private func generateStreamedResponse(
        for messageID: UUID,
        chat: ChatModel,
        isContinued: Bool,
        excludeThinking: Bool,
        trimmedPrompt: String
    ) {
        Task {
            do {
                try chatStore.setChatStatus(for: chatID, to: .loading)
            } catch {
                print("Failed to set chat status: \(error)")
            }

            let originalText = isContinued
                ? chat.messages.first(where: { $0.id == messageID })?.text ?? ""
                : ""
            var rawAccumulator = StreamAccumulator()
            let visibleAccumulator = StreamAccumulator(
                originalText: originalText,
                continuationSeparator: " "
            )
            var reasoningParser = ReasoningStreamParser(
                startsInsideReasoning: connectionManager.connectionSettings.forceThinking
            )
            let stream = languageModelService.sendStreamedMessage(
                chatModel: chat,
                continued: isContinued,
                trimmedPrompt: trimmedPrompt
            )

            for await response in stream {
                let responseText = response.text ?? ""
                let rawResponse = rawAccumulator.ingest(responseText)
                let isFinal = response.streaming == false
                let parsedResponse = excludeThinking
                    ? reasoningParser.parse(rawResponse, isFinal: isFinal)
                    : ReasoningParseResult(visibleText: rawResponse, shouldShowThinking: false)
                let visibleResponse = parsedResponse.visibleText.isEmpty
                    ? ""
                    : visibleAccumulator.combinedVisibleText(parsedResponse.visibleText)

                await applyResponseUpdate(
                    for: messageID,
                    responseText: visibleResponse,
                    disconnect: response.disconnect,
                    isFinal: isFinal,
                    shouldShowThinking: parsedResponse.shouldShowThinking
                )
            }
        }
    }

    private func applyResponseUpdate(
        for messageID: UUID,
        responseText: String,
        disconnect: Bool,
        isFinal: Bool,
        shouldShowThinking: Bool
    ) async {
        guard let chat = model,
            let message = chat.messages.first(where: { $0.id == messageID }) else {
            return
        }

        var updatedMessage = message
        updatedMessage.error = disconnect ? .apiError : .none

        if responseText.isEmpty == false {
            updatedMessage.text = responseText
        }

        if disconnect {
            updatedMessage.text = responseText.isEmpty
                ? "There was an error processing your request. Please try again later."
                : responseText
        }

        updatedMessage.status = isFinal
            ? .done
            : (shouldShowThinking ? .thinking : .streaming)

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id, save: isFinal)
            try chatStore.setChatStatus(
                for: chatID,
                to: isFinal ? .idle : (shouldShowThinking ? .thinking : .streaming)
            )
        } catch {
            print("Failed to update streamed response: \(error)")
        }

        if responseText.isEmpty == false || isFinal {
            updateScrollView.toggle()
        }

        if updatedMessage.status == .streaming {
            triggerHapticIfNeeded()
        }
    }

    private func finalizeDisconnectedMessage(at messageIndex: Int, in chat: ChatModel) async {
        guard chat.messages.indices.contains(messageIndex) else {
            return
        }

        var updatedMessage = chat.messages[messageIndex]
        updatedMessage.error = .disconnect
        updatedMessage.status = .done
        updatedMessage.text = "Looks like you're not connected to a model. Please check your connection settings."

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id)
            try chatStore.setChatStatus(for: chatID, to: .idle)
            updateScrollView.toggle()
        } catch {
            print("Failed to finalize disconnected message: \(error)")
        }
    }

    private func autoTrimPrompt(
        for chat: ChatModel,
        continueResponse: Bool,
        forceThinking: Bool
    ) async -> String {
        let settings = connectionManager.connectionSettings
        guard settings.connectionType == .KoboldAPI else {
            return ""
        }

        return await KoboldPromptContextBuilder(
            tokenCount: { [languageModelService] text in
                await languageModelService.getTokenCount(string: text)
            }
        ).build(
            for: chat,
            settings: settings,
            continueResponse: continueResponse,
            forceThinking: forceThinking,
            includeTemplate: continueResponse == false
        ).prompt
    }

    private func triggerHapticIfNeeded() {
        let now = Date()
        guard isViewActive,
            lastHapticTriggerAt == nil || now.timeIntervalSince(lastHapticTriggerAt!) >= 0.1 else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        lastHapticTriggerAt = now
    }
}
