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
    private let appTheme: AppTheme = ServiceContainer.shared.currentTheme

    private(set) var markdownStreamSource = ChatMarkdownStreamSource()
    private(set) var streamingMessageID: UUID?

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
    var scrollAfterLayout: Bool = false
    var scrollReloadToggle: Int = 0

    var showSettings: Bool = false
    var editingMessageID: UUID?
    var newInstance: Bool = true
    var isViewActive: Bool = false
    var isAutoScrollEnabled: Bool
    var autoScrollSetting: Bool {
        connectionManager.connectionSettings.autoScrollChat
    }

    var disableWhileEditing: Bool = false

    private var lastHapticTriggerAt: Date?

    init(
        chatID: UUID,
        languageModelService: LanguageModelService? = nil,
        connectionManager: ConnectionStatusManager? = nil,
        chatStore: ChatStore? = nil,
        characterStore: CharacterStore? = nil
    ) {
        self.chatID = chatID
        self.languageModelService =
            languageModelService ?? ServiceContainer.shared.getLanguageModelService()
        self.connectionManager =
            connectionManager ?? ServiceContainer.shared.getConnectionStatusManager()
        self.chatStore = chatStore ?? ServiceContainer.shared.getChatStore()
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.isAutoScrollEnabled = self.connectionManager.connectionSettings.autoScrollChat

        Task {
            guard let model = model else {
                print("Model not found yet!")
                return
            }

            // Warm up generation. We ensure the contextManager is initialized on each message
            // send. This will allow the manager to start building the inital context early if
            // a chat is opened long enough before a first send.
            await self.languageModelService.initContextManager(chatModel: model)
        }
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
        updatedMessage.addNewGeneration()
        updatedMessage.error = .none
        updatedMessage.errorTitle = nil
        updatedMessage.errorMessage = nil
        updatedMessage.errorRecoverySuggestion = nil
        updatedMessage.status = .loading

        if continueResponse == false {
            updatedMessage.text = ""
        }

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id, save: false)
            isAutoScrollEnabled = autoScrollSetting
            scrollAfterLayout.toggle()
            scrollReloadToggle += 1
            await generateResponse(for: updatedMessage.id, isContinued: continueResponse)
        } catch {
            print("Failed to regenerate message: \(error)")
        }
    }

    func navigateGeneration(_ message: MessageModel, forward: Bool) async {
        // check if message is the last message in the chat
        guard let chat = model, message.id == chat.messages.last?.id else {
            return
        }

        var updatedMessage = message
        if forward {
            updatedMessage.nextGeneration()
        } else {
            updatedMessage.previousGeneration()
        }

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id)
            isAutoScrollEnabled = autoScrollSetting
            scrollAfterLayout.toggle()
        } catch {
            print("Failed to navigate message generation: \(error)")
        }
    }

    func clearChat() async {
        guard let chat = model else {
            return
        }

        do {
            try await chatStore.resetChat(chat)
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
            if chat.messages.count == 1 {
                // If we only have 1 message (first mes) we can simply clear chat to apply any
                // new changes
                try await chatStore.resetChat(chat)
            }
            try await chatStore.saveChat(chat)

        } catch {
            print("Failed to update chat settings: \(error)")
        }
    }

    func addNote(text: String, depth: Int, injectInMemory: Bool) async {
        guard let chat = model else {
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            return
        }

        let clampedDepth = injectInMemory ? 0 : max(depth, 1)
        let note = ChatNoteModel(
            note: trimmedText,
            depth: clampedDepth,
            injectInMemory: injectInMemory
        )

        do {
            try await chatStore.addChatNote(note, to: chat.id)
        } catch {
            print("Failed to add chat note: \(error)")
        }
    }

    func updateNote(noteID: UUID, text: String, depth: Int, injectInMemory: Bool) async {
        guard var chat = model,
            let noteIndex = chat.chatNotes.firstIndex(where: { $0.id == noteID })
        else {
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            return
        }

        chat.chatNotes[noteIndex].note = trimmedText
        chat.chatNotes[noteIndex].depth = injectInMemory ? 0 : max(depth, 1)
        chat.chatNotes[noteIndex].injectInMemory = injectInMemory
        chat.chatNotes[noteIndex].updatedAt = Date()
        chat.updatedAt = Date()

        do {
            try await chatStore.saveChat(chat)
        } catch {
            print("Failed to update chat note: \(error)")
        }
    }

    func deleteNote(noteID: UUID) async {
        guard var chat = model else {
            return
        }

        chat.chatNotes.removeAll { $0.id == noteID }
        chat.updatedAt = Date()

        do {
            try await chatStore.saveChat(chat)
        } catch {
            print("Failed to delete chat note: \(error)")
        }
    }

    func updateMessage(_ message: MessageModel, newText: String) async {
        guard let chat = model else {
            return
        }

        var updatedMessage = message

        // for KoboldAPI we need to update token count after any edit
        let tokenCount = await languageModelService.getTokenCount(string: newText)
        updatedMessage.updateCurrentGeneration(text: newText, tokenCount: tokenCount)

        do {
            print("updating message")
            try await chatStore.updateMessage(updatedMessage, in: chat.id)
        } catch {
            print("Failed to update message: \(error)")
        }
    }

    func deleteMessage(_ message: MessageModel) async {
        guard let chat = model else {
            return
        }

        disableWhileEditing = false

        do {
            try await chatStore.deleteMessage(message, from: chat.id)
            isAutoScrollEnabled = autoScrollSetting
            scrollAfterLayout.toggle()
            scrollReloadToggle += 1
        } catch {
            print("Failed to delete message: \(error)")
        }
    }

    private func generateResponse(
        for messageID: UUID, isContinued: Bool = false, streamed: Bool = true
    ) async {
        guard let chat = model,
            let messageIndex = chat.messages.firstIndex(where: { $0.id == messageID })
        else {
            return
        }

        guard isConnected else {
            await finalizeDisconnectedMessage(at: messageIndex, in: chat)
            return
        }

        if streamed {
            generateStreamedResponse(
                for: messageID,
                chat: chat,
                isContinued: isContinued,
                excludeThinking: true,  // OpenRouter is sometimes passing <think> tags. We should just open this up as a setting
            )
            return
        }

        let response = await languageModelService.sendMessage(
            chatModel: chat, continued: isContinued)
        let responseText =
            response?.text ?? ""
        let settings = connectionManager.connectionSettings
        let sanitizedResponse = ReasoningStreamParser.visibleText(
            from: responseText,
            thinkingStartSequence: settings.thinkingStartSequence,
            thinkingStopSequence: settings.thinkingStopSequence
        )
        let originalText = isContinued ? chat.messages[messageIndex].text : ""
        let visibleResponse = StreamAccumulator(
            originalText: originalText,
            continuationSeparator: " "
        ).combinedVisibleText(sanitizedResponse)

        await applyResponseUpdate(
            for: messageID,
            responseText: visibleResponse,
            delta: "",
            disconnect: response?.disconnect ?? true,
            isFinal: true,
            shouldShowThinking: false,
            error: response?.error
        )
    }

    private func generateStreamedResponse(
        for messageID: UUID,
        chat: ChatModel,
        isContinued: Bool,
        excludeThinking: Bool
    ) {
        Task {
            let userPersona = ServiceContainer.shared.getPersona

            do {
                try chatStore.setChatStatus(for: chatID, to: .loading)
            } catch {
                print("Failed to set chat status: \(error)")
            }

            let originalText =
                isContinued
                ? chat.messages.first(where: { $0.id == messageID })?.text ?? ""
                : ""
            var rawAccumulator = StreamAccumulator()
            let visibleAccumulator = StreamAccumulator(
                originalText: originalText,
                continuationSeparator: " "
            )
            var reasoningParser = ReasoningStreamParser(
                startsInsideReasoning: connectionManager.connectionSettings.forceThinking,
                thinkingStartSequence: connectionManager.connectionSettings.thinkingStartSequence,
                thinkingStopSequence: connectionManager.connectionSettings.thinkingStopSequence
            )
            // KoboldAPI (text completion) embeds reasoning inline via think tags, so we
            // parse them out of the streamed text. OpenRouter/OpenAI-compatible APIs
            // surface reasoning as a dedicated field with an `isThinking` flag instead.
            let connectionType = ServiceContainer.shared.selectedConnectionType
            let useReasoningParser = connectionType == .KoboldAPI
            let stream = await languageModelService.sendStreamedMessage(
                chatModel: chat,
                userPersona: userPersona,
                continued: isContinued
            )

            for await response in stream {
                let responseText = response.text ?? ""
                let rawResponse = rawAccumulator.ingest(responseText)
                let isFinal = response.streaming == false || response.error != nil
                let parsedResponse: ReasoningParseResult
                if useReasoningParser {
                    parsedResponse =
                        excludeThinking
                        ? reasoningParser.parse(rawResponse, isFinal: isFinal)
                        : ReasoningParseResult(visibleText: rawResponse, shouldShowThinking: false)
                } else {
                    parsedResponse = ReasoningParseResult(
                        visibleText: rawResponse,
                        shouldShowThinking: response.isThinking
                    )
                }
                let visibleResponse =
                    parsedResponse.visibleText.isEmpty
                    ? ""
                    : visibleAccumulator.combinedVisibleText(parsedResponse.visibleText)

                await applyResponseUpdate(
                    for: messageID,
                    responseText: visibleResponse,
                    delta: response.deltaText ?? "",
                    disconnect: response.disconnect || response.error != nil,
                    isFinal: isFinal,
                    shouldShowThinking: parsedResponse.shouldShowThinking,
                    error: response.error
                )
            }
        }
    }

    private func applyResponseUpdate(
        for messageID: UUID,
        responseText: String,
        delta: String,
        disconnect: Bool,
        isFinal: Bool,
        shouldShowThinking: Bool,
        error: LLMError? = nil
    ) async {
        guard let chat = model,
            let message = chat.messages.first(where: { $0.id == messageID })
        else {
            return
        }

        let targetMessageStatus: MessageStatus =
            isFinal
            ? .done
            : (shouldShowThinking ? .thinking : .streaming)
        let targetChatStatus: ChatStatus =
            isFinal ? .idle : (shouldShowThinking ? .thinking : .streaming)
        let shouldCommitMessage =
            isFinal
            || disconnect
            || message.status != targetMessageStatus
        let shouldCommitChatStatus = chat.status != targetChatStatus

        var updatedMessage = message
        let displayError = error.map(AppLLMErrorDisplay.from)
        updatedMessage.error = disconnect ? .apiError : .none
        updatedMessage.errorTitle = displayError?.title
        updatedMessage.errorMessage = displayError?.message
        updatedMessage.errorRecoverySuggestion = displayError?.recoverySuggestion
        updatedMessage.status = targetMessageStatus

        if isFinal || disconnect {
            if responseText.isEmpty == false {
                updatedMessage.text = responseText
            }

            if disconnect {
                updatedMessage.text =
                    responseText.isEmpty
                    ? updatedMessage.text
                    : responseText
            }
        }

        // for KoboldAPI we need to fetch token count after full message is received
        let currentModel = ServiceContainer.shared.selectedModelName
        let currentConnectionType = ServiceContainer.shared.selectedConnectionType
        if isFinal && currentConnectionType == .KoboldAPI {
            //            let tokenCount = await languageModelService.getTokenCount(string: updatedMessage.text)
            //            updatedMessage.tokenCount = tokenCount
            updatedMessage.tokenCountModel = currentModel
        }

        if isFinal {
            markdownStreamSource.finish()
            streamingMessageID = nil
        } else if responseText.isEmpty == false && shouldShowThinking == false {
            if streamingMessageID != messageID {
                markdownStreamSource = ChatMarkdownStreamSource()
                streamingMessageID = messageID
            }
            markdownStreamSource.yieldSnapshot(responseText)
        }

        ChatPerformanceInstrumentation.streamingUpdate(
            messageID: messageID,
            responseLength: responseText.count,
            deltaLength: delta.count,
            isFinal: isFinal,
            shouldShowThinking: shouldShowThinking,
            willUpdateStore: shouldCommitMessage || shouldCommitChatStatus
        )

        if shouldCommitMessage || shouldCommitChatStatus {
            do {
                if shouldCommitMessage {
                    try await chatStore.updateMessage(updatedMessage, in: chat.id, save: isFinal)
                }

                if shouldCommitChatStatus {
                    try chatStore.setChatStatus(for: chatID, to: targetChatStatus)
                }
            } catch {
                print("Failed to update streamed response: \(error)")
            }
        }

        if isFinal {
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
        updatedMessage.errorTitle = "API Disconnected"
        updatedMessage.errorMessage =
            "Looks like you're not connected to a model. Please check your connection settings."
        updatedMessage.errorRecoverySuggestion = "Tap the connection banner to open Settings."
        updatedMessage.status = .done

        do {
            try await chatStore.updateMessage(updatedMessage, in: chat.id)
            try chatStore.setChatStatus(for: chatID, to: .idle)
            updateScrollView.toggle()
        } catch {
            print("Failed to finalize disconnected message: \(error)")
        }
    }

    private func triggerHapticIfNeeded() {
        let now = Date()
        guard isViewActive,
            lastHapticTriggerAt == nil || now.timeIntervalSince(lastHapticTriggerAt!) >= 0.2
        else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        lastHapticTriggerAt = now
    }
}
