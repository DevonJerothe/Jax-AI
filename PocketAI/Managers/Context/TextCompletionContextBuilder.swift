import Foundation 
import SwiftLLMSDK
import SwiftTiktoken

// MARK: - Prompt Builders
struct TextCompletionContextBuilder {
    private var tokenCache: TokenCountCache = .init()

    private struct RenderedContextBlock {
        let source: ContextBlock
        let renderedText: String
        let tokenCount: Int

        var priority: ContextBlock.Priority {
            source.priority
        }

        var order: Int {
            source.order
        }

        // sort function
        static func sort(
            _ lhs: RenderedContextBlock,
            _ rhs: RenderedContextBlock
        ) -> Bool {
            if lhs.priority != rhs.priority {
                return lhs.priority.rawValue < rhs.priority.rawValue
            }
            return lhs.order < rhs.order
        }
    }

    func render(
        memoryBlocks: [ContextBlock],
        promptBlocks: [ContextBlock],
        settings: ConnectionSettingsModel,
        continued: Bool = false,
        forceThinking: Bool = false,
        tokenizer: CoreBPE
    ) -> TextCompletionContent {

        let maxContextTokens = settings.contextLength ?? 4096
        let reservedResponseTokens = settings.responseLength ?? 240
        let availableContextTokens = max(0, maxContextTokens - reservedResponseTokens)

        let renderedMemBlocks = renderMemoryBlock(memoryBlocks, tokenizer: tokenizer)
        let renderedPromptBlocks = renderPromptBlock(
            promptBlocks,
            settings: settings,
            continued: continued,
            forceThinking: forceThinking,
            tokenizer: tokenizer
        )

        // select memory blocks
        let selectedMemoryBlocks = selectMemoryBlocks(
            renderedMemBlocks,
            tokenBudget: availableContextTokens
        )
        let selectedMemoryTokens = selectedMemoryBlocks.reduce(0) {
            $0 + $1.tokenCount
        }
        let remainingPromptBudget = max(0, availableContextTokens - selectedMemoryTokens)

        // select prompt blocks
        let selectedPromptBlocks = selectPromptBlocks(
            renderedPromptBlocks,
            tokenBudget: remainingPromptBudget
        )
        let selectedPromptTokens = selectedPromptBlocks.reduce(0) {
            $0 + $1.tokenCount
        }

        return TextCompletionContent(
            memory: selectedMemoryBlocks.map(\.renderedText).joined(separator: "\n"),
            prompt: selectedPromptBlocks.map(\.renderedText).joined(),
            tokenCount: .init(
                maxContextTokens: maxContextTokens,
                reservedResponseTokens: reservedResponseTokens,
                availableContextTokens: availableContextTokens - selectedMemoryTokens
                    - selectedPromptTokens,
                selectedMemoryTokens: selectedMemoryTokens,
                selectedPromptTokens: selectedPromptTokens
            )
        )
    }

    private func renderMemoryBlock(
        _ blocks: [ContextBlock],
        tokenizer: CoreBPE
    ) -> [RenderedContextBlock] {
        var renderedBlocks: [RenderedContextBlock] = []

        for block in blocks {
            var renderText = ""
            switch block.kind {
            case .characterDescription:
                renderText = "[Description]\n\(block.text)"
            case .characterPersonality:
                renderText = "[Personality]\n\(block.text)"
            case .characterScenario:
                renderText = "[Scenario]\n\(block.text)"
            case .persona:
                renderText = "[Persona]\n\(block.text)"
            case .system:
                renderText = "[System]\n\(block.text)"
            case .userNote:
                renderText = "[Story Note]\n\(block.text)"
            case .characterMessageExample:
                renderText = "[Character Message Example]\n\(block.text)"
            default:
                renderText = block.text
            }

            guard renderText.isEmpty == false else {
                continue
            }

            let tokens = tokenCache.count(renderText, tokenizer: tokenizer)
            renderedBlocks.append(
                RenderedContextBlock(
                    source: block,
                    renderedText: renderText,
                    tokenCount: tokens
                ))
        }

        return renderedBlocks
    }

    private func renderPromptBlock(
        _ blocks: [ContextBlock],
        settings: ConnectionSettingsModel,
        continued: Bool,
        forceThinking: Bool,
        tokenizer: CoreBPE
    ) -> [RenderedContextBlock] {
        let sortedBlocks = blocks.sorted { $0.order < $1.order }
        let firstBotMessagedID = sortedBlocks.first(where: {
            $0.actor == .assistant && $0.kind == .message
        })?.sourceID
        let lastUserMessageID = sortedBlocks.last(where: {
            $0.actor == .user && $0.kind == .message
        })?.sourceID

        var renderedBlocks: [RenderedContextBlock] = []

        for block in sortedBlocks {
            var renderedText = ""
            switch block.actor {
            case .system:
                renderedText = "\(settings.systemStopSequence)\n\(block.text)"
            case .assistant:
                let prefix =
                    block.sourceID == firstBotMessagedID
                    ? settings.botStopSequence
                    : ""
                let suffix = continued ? "" : settings.userStopSequence
                renderedText = "\(prefix)\(block.text)\(suffix)"
            case .user:
                var text = "\(block.text)\(settings.botStopSequence)"
                if settings.botStopSequence.isEmpty == false {
                    text += " "
                }
                if forceThinking && block.sourceID == lastUserMessageID {
                    text += "\(settings.thinkingStartSequence)\n\(settings.forceThinkingInstruct)"
                }
                renderedText = text
            default:
                continue
            }

            guard renderedText.isEmpty == false else {
                continue
            }

            let tokens = tokenCache.count(renderedText, tokenizer: tokenizer)

            renderedBlocks.append(
                RenderedContextBlock(
                    source: block,
                    renderedText: renderedText,
                    tokenCount: tokens
                )
            )
        }

        return renderedBlocks
    }

    private func selectMemoryBlocks(
        _ blocks: [RenderedContextBlock],
        tokenBudget: Int
    ) -> [RenderedContextBlock] {
        var remaining = tokenBudget
        var selected: [RenderedContextBlock] = []

        // get all required blocks first
        let requiredBlocks = blocks.filter { $0.priority == .required }.sorted(
            by: RenderedContextBlock.sort)
        for block in requiredBlocks {
            selected.append(block)
            remaining -= block.tokenCount
        }

        let nonRequiredBlocks = blocks.filter { $0.priority != .required }.sorted(
            by: RenderedContextBlock.sort)
        for block in nonRequiredBlocks {
            guard block.tokenCount <= remaining else {
                continue
            }

            selected.append(block)
            remaining -= block.tokenCount
        }

        return selected.sorted(by: RenderedContextBlock.sort)
    }

    private func selectPromptBlocks(
        _ blocks: [RenderedContextBlock],
        tokenBudget: Int
    ) -> [RenderedContextBlock] {
        let sortedBlocks = blocks.sorted { $0.order < $1.order }

        var remaining = tokenBudget
        var selectedBlocks: [RenderedContextBlock] = []

        for block in sortedBlocks.reversed() {
            if block.tokenCount <= remaining {
                selectedBlocks.append(block)
                remaining -= block.tokenCount
            } else {
                break
            }
        }

        // if we hit limit by memory alone we should make sure no notes are inlcuded with the suffix value
        if selectedBlocks.isEmpty {
            let filteredMessages = sortedBlocks.filter { $0.source.kind == .message }
            return Array(filteredMessages.suffix(2))
        }

        return selectedBlocks.reversed()
    }
}