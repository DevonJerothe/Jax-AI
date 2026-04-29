import Foundation

struct TokenBudget {
    let maxContextTokens: Int
    let reservedResponseTokens: Int
    let memoryTokens: Int
    let templateTokens: Int

    var messageTokens: Int {
        maxContextTokens - reservedResponseTokens - memoryTokens - templateTokens
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
    let tokenCount: (String) async -> Int

    func build(
        for chat: ChatModel,
        settings: ConnectionSettingsModel,
        continueResponse: Bool,
        forceThinking: Bool,
        includeTemplate: Bool
    ) async -> PromptContext {
        let memory = chat.getFullMemory()
        let template = includeTemplate
            ? settings.userTemplates.values
                .filter(\.isEnabled)
                .map(\.content)
                .joined(separator: "\n")
            : ""

        let maxContextTokens = settings.contextLength ?? 4096
        let reservedResponseTokens = settings.responseLength ?? 240
        let memoryTokens = await tokenCount(memory)
        let templateTokens = await tokenCount(template)
        let budget = TokenBudget(
            maxContextTokens: maxContextTokens,
            reservedResponseTokens: reservedResponseTokens,
            memoryTokens: memoryTokens,
            templateTokens: templateTokens
        )

        let blocks = await messageBlocks(
            for: chat,
            settings: settings,
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
        continueResponse: Bool,
        forceThinking: Bool
    ) async -> [MessageBlock] {
        let lastUserID = chat.messages.last(where: { $0.actor == .user })?.id
        let firstBotID = chat.messages.first(where: { $0.actor == .bot })?.id
        var blocks: [MessageBlock] = []

        for message in chat.messages {
            guard message.exclude == false else {
                continue
            }

            let text: String
            switch message.actor {
            case .user:
                var userText = "\(message.text)\(settings.botStopSequence)"
                if settings.botStopSequence.isEmpty == false {
                    userText += " "
                }
                if forceThinking && message.id == lastUserID {
                    userText += "\(settings.thinkingStartSequence)\n\(settings.forceThinkingInstruct)"
                }
                text = userText

            case .bot:
                guard message.status == .done || continueResponse else {
                    continue
                }
                let suffix = continueResponse ? "" : settings.userStopSequence
                let prefix = firstBotID == message.id ? settings.botStopSequence : "" 
                text = "\(prefix)\(message.text)\(suffix)"
            }

            blocks.append(
                MessageBlock(
                    id: message.id,
                    text: text,
                    tokens: await tokenCount(text)
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
