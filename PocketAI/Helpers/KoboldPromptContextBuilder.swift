import Foundation

struct TokenBudget {
    let maxContextTokens: Int
    let reservedResponseTokens: Int
    let memoryTokens: Int
    let templateTokens: Int
    let personaTokens: Int

    var messageTokens: Int {
        maxContextTokens - reservedResponseTokens - memoryTokens - templateTokens - personaTokens
    }
}

struct PromptContext {
    let prompt: String
    let memory: String
    let template: String
    let includedMessageIDs: [UUID]
    let tokenBudget: TokenBudget
}

struct KoboldPromptContextBuilder {

    // used for memory context and fallback message token count in case message content contains 0
    let tokenCount: (String) async -> Int
    
    func build(
        for chat: ChatModel,
        settings: ConnectionSettingsModel,
        userPersona: UserPersonaModel?,
        continueResponse: Bool,
        forceThinking: Bool,
        includeTemplate: Bool
    ) async -> PromptContext {
        let memory = chat.getFullMemory(userPersona: userPersona)
        let template = includeTemplate
            ? settings.userTemplates.values
                .filter(\.isEnabled)
                .map(\.content)
                .joined(separator: "\n")
            : ""
        let personaDescription = userPersona?.description ?? ""

        let maxContextTokens = settings.contextLength ?? 4096
        let reservedResponseTokens = settings.responseLength ?? 240
        let memoryTokens = await tokenCount(memory)
        let templateTokens = await tokenCount(template)
        let personaTokens = await tokenCount(personaDescription)
        
        let budget = TokenBudget(
            maxContextTokens: maxContextTokens,
            reservedResponseTokens: reservedResponseTokens,
            memoryTokens: memoryTokens,
            templateTokens: templateTokens,
            personaTokens: personaTokens
        )

        let blocks = await messageBlocks(
            for: chat,
            settings: settings,
            userPersona: userPersona,
            continueResponse: continueResponse,
            forceThinking: forceThinking
        )

        let selectedBlocks: [MessageBlock]
        if budget.messageTokens <= 0 {
            selectedBlocks = Array(blocks.suffix(2))
        } else {
            selectedBlocks = selectRecentBlocks(from: blocks, tokenBudget: budget.messageTokens)
        }

        return PromptContext(
            prompt: selectedBlocks.map(\.text).joined(),
            memory: memory,
            template: template,
            includedMessageIDs: selectedBlocks.map(\.id),
            tokenBudget: budget
        )
    }

    private struct MessageBlock {
        let id: UUID
        let text: String
        let tokens: Int
    }

    private func messageBlocks(
        for chat: ChatModel,
        settings: ConnectionSettingsModel,
        userPersona: UserPersonaModel?,
        continueResponse: Bool,
        forceThinking: Bool
    ) async -> [MessageBlock] {
        let lastUserID = chat.messages.last(where: { $0.actor == .user })?.id
        let firstBotID = chat.messages.first(where: { $0.actor == .bot })?.id
        var blocks: [MessageBlock] = []

        let personaName = userPersona?.name ?? "User"

        for message in chat.messages {
            var message = message
            guard message.exclude == false else {
                continue
            }

            // NOTE: Token count may not be accurate depending on personal and character names. This may be negligible, but we may want
            // to seperately count persona tokens later. 
            // In most cases the char and user names will be included in the LLM response. This is likely to only affect memory and initial messages. 
            let text: String
            switch message.actor {
            case .user:
                let messageText = message.text
                    .replacingOccurrences(of: "{{char}}", with: chat.chatTitle)
                    .replacingOccurrences(of: "{{user}}", with: personaName)
                
                var userText = "\(messageText)\(settings.botStopSequence)"
                if settings.botStopSequence.isEmpty == false {
                    userText += " "
                }
                if forceThinking && message.id == lastUserID {
                    userText += "\(settings.thinkingStartSequence)\n\(settings.forceThinkingInstruct)"
                }
                text = userText

            case .bot:
                let messageText = message.text
                    .replacingOccurrences(of: "{{char}}", with: chat.chatTitle)
                    .replacingOccurrences(of: "{{user}}", with: personaName)
                
                guard message.status == .done || continueResponse else {
                    continue
                }
                let suffix = continueResponse ? "" : settings.userStopSequence
                let prefix = firstBotID == message.id ? settings.botStopSequence : "" 
                text = "\(prefix)\(messageText)\(suffix)"
            }

            // fetch token count if needed. 
            let currentModel = await ServiceContainer.shared.selectedModelName
            let needsTokenRefresh = message.tokenCountModel == nil
                || (currentModel != nil && message.tokenCountModel != currentModel)
                || message.tokenCount == 0

            if needsTokenRefresh {
                let tokens = await tokenCount(text)
                // save new value to record 
                message.tokenCount = tokens
                message.tokenCountModel = currentModel

                do {
                    try await ServiceContainer.shared.getChatStore().updateMessage(message, in: chat.id)
                } catch {
                    print("Failed to update message token count: \(error)")
                }
            }
            
            blocks.append(
                MessageBlock(
                    id: message.id,
                    text: text,
                    tokens: message.tokenCount
                )
            )
        }

        return blocks
    }

    private func selectRecentBlocks(
        from blocks: [MessageBlock],
        tokenBudget: Int
    ) -> [MessageBlock] {
        var remaining = tokenBudget
        var selectedReversed: [MessageBlock] = []

        for block in blocks.reversed() {
            if block.tokens <= remaining {
                selectedReversed.append(block)
                remaining -= block.tokens
            } else {
                break
            }
        }

        if selectedReversed.isEmpty {
            return Array(blocks.suffix(2))
        }

        return selectedReversed.reversed()
    }
}
