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
        case loreBook
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

enum ContextMemoryOrder {
    static let loreBeforeCharacter = -1_000_000_000

    static let characterDescription = 0
    static let characterPersonality = 10
    static let characterScenario = 20
    static let characterMessageExample = 30
    static let characterSystemPrompt = 40

    static let loreAfterCharacter = 1_000_000

    static let system = 1_000_000_000
    static let userNote = 1_000_000_010
    static let persona = 1_000_000_020
}

enum ContextPromptOrder {
    static let firstMessage = 1_000_000_000
    static let messageShift = 1_000_000_000
    static let loreOffset = -500_000_000
    static let noteOffset = -1

    static func message(index: Int) -> Int {
        firstMessage + (index * messageShift)
    }

    static func insertionIndex(depth: Int, visibleMessageCount: Int) -> Int {
        let safeDepth = max(0, depth)
        return min(visibleMessageCount, max(0, visibleMessageCount - safeDepth))
    }

    static func loreAtDepth(
        _ depth: Int,
        visibleMessageCount: Int,
        entryOrderOffset: Int = 0
    ) -> Int {
        message(index: insertionIndex(depth: depth, visibleMessageCount: visibleMessageCount))
            + loreOffset + entryOrderOffset
    }

    static func noteAtDepth(_ depth: Int, visibleMessageCount: Int) -> Int {
        message(index: insertionIndex(depth: depth, visibleMessageCount: visibleMessageCount))
            + noteOffset
    }

    static func loreBeforeMessage(index: Int) -> Int {
        message(index: index) + loreOffset
    }

    static func noteBeforeMessage(index: Int) -> Int {
        message(index: index) + noteOffset
    }
}
