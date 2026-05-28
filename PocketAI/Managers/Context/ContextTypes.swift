import Foundation
import SwiftLLMSDK

struct ContextBlock {
    enum Kind {
        case system
        case characterDescription
        case characterPersonality
        case characterScenario
        case characterMessageExample
        case characterSysPrompt
        case persona
        case userNote
        case summary
        case message
    }

    enum Priority: Int {
        case required = 0
        case high = 1
        case low = 2
        case optional = 3
    }

    enum Target {
        case memory
        case prompt
    }

    let kind: Kind
    let priority: Priority
    let text: String
    let tokenCount: Int
    let target: Target
    var order: Int
    var actor: OpenRouterMessageRole
    let sourceID: UUID?

    init(
        kind: Kind,
        priority: Priority,
        text: String,
        tokenCount: Int,
        target: Target,
        order: Int = 0,  // Order is mostly used for prompt target. So we can leave 0 as default for others.
        actor: OpenRouterMessageRole = .system,
        sourceID: UUID? = nil
    ) {
        self.kind = kind
        self.priority = priority
        self.text = text
        self.tokenCount = tokenCount
        self.target = target
        self.order = order
        self.actor = actor
        self.sourceID = sourceID
    }
}

struct TextCompletionContent {
    let memory: String
    let prompt: String
    let tokenCount: ContextBudget
}

struct ChatCompletionContent {
    let messages: [RequestBodyMessages]
    let tokenCount: ContextBudget
}

struct ContextBudget {
    let maxContextTokens: Int
    let reservedResponseTokens: Int
    let availableContextTokens: Int
    let selectedMemoryTokens: Int
    let selectedPromptTokens: Int

    var totalSelectedTokens: Int {
        selectedMemoryTokens + selectedPromptTokens
    }
}

enum ContextOutput {
    case textCompletion(TextCompletionContent)
    case chatCompletion(ChatCompletionContent)
    case error(String)

    var textCompletion: TextCompletionContent? {
        if case .textCompletion(let content) = self {
            return content
        }
        return nil
    }

    var chatCompletion: ChatCompletionContent? {
        if case .chatCompletion(let content) = self {
            return content
        }
        return nil
    }

    var error: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}