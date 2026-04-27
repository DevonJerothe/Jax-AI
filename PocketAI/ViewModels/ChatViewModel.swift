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

    func updateChatSettings(characterCard: CharacterCardModel) async {
        guard var chat = model else {
            return
        }

        chat.characterCards = [characterCard]
        chat.memory = characterCard.description ?? chat.memory
        chat.isPrivate = characterCard.isPrivate

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
        let sanitizedResponse = sanitizeThinking(from: responseText)

        await applyResponseUpdate(
            for: messageID,
            isContinued: isContinued,
            responseText: sanitizedResponse,
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

            let stream = languageModelService.sendStreamedMessage(
                chatModel: chat,
                continued: isContinued,
                trimmedPrompt: trimmedPrompt
            )

            for await response in stream {
                let responseText = response.text ?? ""
                let firstNonWhitespaceChar = responseText.first(where: { !$0.isWhitespace })
                let didThinkingStart = firstNonWhitespaceChar == "<" || connectionManager.connectionSettings.forceThinking
                let didThinkingFinish = responseText.contains("</think>") || isContinued
                let shouldShowThinking = didThinkingStart && !didThinkingFinish
                let visibleResponse = (!excludeThinking || didThinkingFinish || !didThinkingStart)
                    ? sanitizeThinking(from: responseText)
                    : ""

                await applyResponseUpdate(
                    for: messageID,
                    isContinued: isContinued,
                    responseText: visibleResponse,
                    disconnect: response.disconnect,
                    isFinal: response.streaming == false,
                    shouldShowThinking: shouldShowThinking
                )
            }
        }
    }

    private func applyResponseUpdate(
        for messageID: UUID,
        isContinued: Bool,
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
            updatedMessage.text = mergedResponseText(
                currentText: updatedMessage.text,
                incomingText: responseText,
                isContinued: isContinued
            )
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

    private func mergedResponseText(
        currentText: String,
        incomingText: String,
        isContinued: Bool
    ) -> String {
        guard incomingText.isEmpty == false else {
            return currentText
        }

        if isContinued || currentText.isEmpty {
            return incomingText
        }

        // Some providers stream deltas while others resend the full partial text.
        // Prefer the incoming value when it already contains what we have, otherwise
        // append the new chunk so text visibly streams into the bubble.
        if incomingText.hasPrefix(currentText) {
            return incomingText
        }

        return currentText + incomingText
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
        
        // We only handle context for KoboldAPI until we can include a token counter in app.
        guard settings.connectionType == .KoboldAPI else {
            return ""
        }
        
        let maxContextTokens = settings.contextLength ?? 4096
        let reservedResponseTokens = settings.responseLength ?? 240
        let memory = chat.getFullMemory()
        let memoryTokens = await languageModelService.getTokenCount(string: memory)
        let userTemplates = settings.userTemplates.values
            .filter(\.isEnabled)
            .map(\.content)
            .joined(separator: "\n")
        let systemTokens = await languageModelService.getTokenCount(string: userTemplates)

        var prefix = "\nAssistant: "
        if forceThinking {
            prefix += "<think>\nOk, first we need to consider who we are and not to speak for the user."
        }

        let prefixTokens = await languageModelService.getTokenCount(string: prefix)
        var fixedOverhead = memoryTokens + prefixTokens + reservedResponseTokens
        if continueResponse {
            fixedOverhead += systemTokens
        }

        /// TODO: this is broken. memory will contain our character context. If we 
        /// over context at this point, this will not send any of our messages including the recent one. 
        /// We need to at a minimum return the last two messages or the bot will have 0 conversation history.
        if fixedOverhead >= maxContextTokens {
            return prefix
        }

        struct Block {
            let text: String
            let tokens: Int
        }

        let lastUserID = chat.messages.last(where: { $0.actor == .user })?.id

        var blocks: [Block] = []
        for message in chat.messages {
            switch message.actor {
            case .user:
                var text = "\(message.text)\nAssistant: "
                if forceThinking && message.id == lastUserID {
                    text += "<think>\nOk, first we need to consider who we are and not to speak for the user."
                }

                let tokens = await languageModelService.getTokenCount(string: text)
                blocks.append(Block(text: text, tokens: tokens))
            case .bot:
                if message.status == .done || continueResponse {
                    let suffix = continueResponse ? "" : "\nUser:"
                    let text = "\(message.text)\(suffix)"
                    let tokens = await languageModelService.getTokenCount(string: text)
                    blocks.append(Block(text: text, tokens: tokens))
                }
            }
        }

        var remaining = maxContextTokens - fixedOverhead
        var selectedReversed: [Block] = []

        for block in blocks.reversed() {
            if block.tokens <= remaining {
                selectedReversed.append(block)
                remaining -= block.tokens
            } else {
                break
            }
        }

        selectedReversed = selectedReversed.reversed()
        var prompt = "" 
        for block in selectedReversed {
            prompt += block.text
        }
        return prompt
    }

    private func sanitizeThinking(from responseText: String) -> String {
        responseText
            .replacing(/\A[\s\S]*?<\/think>\s*/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
