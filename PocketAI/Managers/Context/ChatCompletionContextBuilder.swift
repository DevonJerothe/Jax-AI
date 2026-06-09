import Foundation
import SwiftLLMSDK
import SwiftTiktoken

// We should still handle context when using ChatCompletion API's. 
// Before this we should determine how to know the context limit of the selected model
struct ChatCompletionContextBuilder {
    func render(
        memoryBlocks: [ContextBlock],
        promptBlocks: [ContextBlock],
        settings: ConnectionSettingsModel,
        continued: Bool = false,
        forceThinking: Bool = false, 
        tokenizer: CoreBPE
    ) -> ChatCompletionContent {
        var requestMessages: [RequestBodyMessages] = []

        let sortedMemoryBlocks = memoryBlocks.sorted { $0.order < $1.order }
        for memoryMessage in sortedMemoryBlocks {

            let renderedText = renderSystemMessage(memoryMessage)
            
            requestMessages.append(
                RequestBodyMessages(role: memoryMessage.actor, message: renderedText)
            )
        }
        
        /// map message blocks to `RequestBodyMessages`
        let sortedMessages = promptBlocks.sorted { $0.order < $1.order }
        for message in sortedMessages {
            requestMessages.append(
                RequestBodyMessages(role: message.actor, message: message.text)
            )
        }

        // If we are continueing a message, we need to add special instructions to the system message.
        // If we are not continuing but the message is loading, we can assume we are regenerating the same message.
        // Pulled this instruction from SillyTavern.
        let lastMessage = requestMessages.last { $0.role == .assistant }
        if continued {
            if let lastMessage = lastMessage?.message {
                let continueMessage = TemplateInstructions().continueMessage(lastMessage)
                requestMessages.append(RequestBodyMessages(role: .system, message: continueMessage))
            }
        } else if let lastMessage, lastMessage.message.isEmpty == true {
            requestMessages.removeAll(where: { $0.id == lastMessage.id })
        }
        
        return ChatCompletionContent(
            messages: requestMessages,
            tokenCount: .init(
                maxContextTokens: 100000, // replace with the model context limit via some API
                reservedResponseTokens: settings.responseLength ?? 240,
                availableContextTokens: 100000,
                selectedMemoryTokens: sortedMemoryBlocks.reduce(0) { $0 + $1.tokenCount },
                selectedPromptTokens: sortedMessages.reduce(0) { $0 + $1.tokenCount }
            )
        )
    }

    private func renderSystemMessage(
        _ block: ContextBlock
    ) -> String {
        switch block.kind {
            case .characterDescription: 
                return "<character_description>\n\(block.text)\n</character_description>"
            case .characterScenario: 
                return "<character_scenario>\n\(block.text)\n</character_scenario>"
            case .characterPersonality:
                return "<character_personality>\n\(block.text)\n</character_personality>"
            case .characterMessageExample:
                return "<character_message_example>\n\(block.text)\n</character_message_example>"
            case .persona: 
                return "<user_persona>\n\(block.text)\n</user_persona>"
            case .userNote: 
                return "<user_note>\n\(block.text)\n</user_note>"
            case .summary:
                return "<chat_summary>\n\(block.text)\n</chat_summary>"
            case .loreBook: 
                return "<lore_entry>\n\(block.text)\n</lore_entry>"
            default: 
                return block.text
        }
    }
}
