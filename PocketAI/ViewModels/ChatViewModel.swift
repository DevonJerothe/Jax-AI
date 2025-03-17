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
class ChatViewModel {
    var llm: KoboldAPI?

    var model: ChatModel
    var updateScrollView: Bool = false
    var showSettings: Bool = false

    var selectionModeActive: Bool = false
    var selectedMessages: Set<MessageModel> = []

    init(
        chatModel: ChatModel,
        llm: KoboldAPI?
    ) {
        self.llm = llm
        self.model = chatModel
    }

    func fetchModel() async {
        let name = await llm?.getModel()
        switch name {
            case .success(let name):
                self.model.modelName = name
            case .failure(let error):
                self.model.error = error.localizedDescription
        case .none:
            print("not connected")
        }
    }

    func fetchMaxContextLength() async {
        let maxContext = await llm?.getMaxContextLength()
        switch maxContext {
            case .success(let maxContext):
                self.model.maxContextLength = maxContext
            case .failure(let error):
                self.model.error = error.localizedDescription
        case .none:
            print("not connected")
        }
    }

    func sendMessage(prompt: String) async {
        await MainActor.run {
            if !prompt.isEmpty {
                self.model.addMessage(prompt, forActor: .user)
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
    }

    func updateChatSettings(
        memory: String,
        firstMessage: String
    ) {
        self.model.memory = memory
        self.model.firstMessage = firstMessage

        print(self.model.memory)
        print(self.model.firstMessage)

        self.showSettings.toggle()

        try! self.model.save()
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
        try! self.model.save()
    }

    func cancelDeleteMessages() {
        selectedMessages.removeAll()
        selectionModeActive = false
    }

    func shouldShowToolbar(_ message: MessageModel) -> Bool {
        if let lastBotIndex = model.messages.lastIndex(where: { $0.actor == .bot }), lastBotIndex != 0 {
            return model.messages[lastBotIndex].id == message.id
        }
        return false
    }

    private func isBelowContextLimit() -> Bool {
        return true
    }

    private func generateResponse(_ forIndex: Int, isContinued: Bool = false) async {
        let promptModel: PromptModel = PromptModel(prompt: model.getFullPrompt(continueResponse: isContinued), memory: model.memory, promptTemplate: TemplatePrompts().defaultRolePlayPrompt)

        print("prompt: \(promptModel.memory)")

        let response = await llm?.sendMessage(promptModel: promptModel)

        switch response {
        case .success(let response):
            let responseText = response.results.first?.text ?? "ERROR"
            await MainActor.run {
                if isContinued {
                    self.model.messages[forIndex].text.append(responseText)
                } else {
                    self.model.messages[forIndex].text = responseText
                }
                self.model.messages[forIndex].loading = false
                try! self.model.messages[forIndex].save()
                self.updateScrollView.toggle()
            }
        case .failure(let error):
            self.model.error = error.localizedDescription
        case .none:
            print("not connected")
        }
    }
}
