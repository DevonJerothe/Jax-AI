import Foundation 
import SwiftTiktoken
import SwiftLLMSDK

struct ContextBlock {
    enum Kind {
        case system
        case characterDescription
        case characterPersonality
        case characterScenario
        case characterMessageExample
        case characterSysPromp
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
    let sourceID: UUID? 

    init(
        kind: Kind,
        priority: Priority,
        text: String,
        tokenCount: Int,
        target: Target,
        order: Int = 0, // Order is mostly used for prompt target. So we can leave 0 as default for others. 
        sourceID: UUID? = nil
    ) {
        self.kind = kind
        self.priority = priority
        self.text = text
        self.tokenCount = tokenCount
        self.target = target
        self.order = order
        self.sourceID = sourceID
    }
}

struct TextCompletionContent {
    let memory: String 
    let prompt: String
    let tokenCount: Int
}

struct ChatCompletionContent {
    let messages: [RequestBodyMessages]
    let tokenCount: Int 
}

// We should build a context manager for each chat instance. This should handle all token counting and 
// budgeting as we continue chatting with the bot
final class ContextManager {
    private(set) var settings: ConnectionStatusManager
    private(set) var chat: ChatModel
    
    private var tokenizer: CoreBPE?
    private var tokenCache: TokenCountCache = .init()
    private var contextBlocks: [ContextBlock] = []

    // Return token count for current memory blocks. This include non required context
    // and may be more than actual based on filtering
    var totalMemoryContext: Int {
        contextBlocks.filter {
            $0.target == .memory 
        }.reduce(0) { $0 + $1.tokenCount }
    }

    // token count of all required memory blocks
    // this count will always be injected and counted towards context.
    var requiredContext: Int {
        contextBlocks.filter { 
            ($0.priority == .required && $0.target == .memory)
        }.reduce(0) { $0 + $1.tokenCount }
    }

    init(
        from chat: ChatModel, 
        _ settings: ConnectionStatusManager
    ) {
        self.settings = settings
        self.chat = chat

        Task {
            self.tokenizer = await ServiceContainer.shared.tokenizer
            await self.loadContextFromChat()
        }
    }

    private func loadContextFromChat() async {
        guard let characterCard = chat.characterCards.first else {
            return
        }

        // character blocks 
        await buildCharachterBlocks(characterCard)
        // system prompts and other memory blocks
        await buildMemoryBlocks()
    }

    private func getTokenCount(text: String?) async -> Int? {
        guard let text = text, text.isEmpty == false else {
            return nil
        }
        
        if tokenizer == nil {
           self.tokenizer = try? await CoreBPE.cl100kBase() 
        }

        guard let tokenizer = tokenizer else {
            return nil
        }

        let tokens = tokenCache.count(text, tokenizer: tokenizer)

        return tokens
    }
} 

extension ContextManager {
    private func buildCharachterBlocks(_ characterCard: CharacterCardModel) async {
        let persona = await ServiceContainer.shared.getPersona

        if let description = characterCard.description?.replaceChatSequences(user: persona?.name, char: chat.chatTitle), let charDescriptionTokens = await getTokenCount(text: description) {
            let charDescriptionBlock = ContextBlock(
                kind: .characterDescription,
                priority: .required,
                text: description,
                tokenCount: charDescriptionTokens,
                target: .memory
            )
            contextBlocks.append(charDescriptionBlock)
        }

        // character personality block
        if let personality = characterCard.personality?.replaceChatSequences(user: persona?.name, char: chat.chatTitle), let charPersonalityTokens = await getTokenCount(text: personality) {
            let charPersonalityBlock = ContextBlock(
                kind: .characterPersonality,
                priority: .required,
                text: personality,
                tokenCount: charPersonalityTokens,
                target: .memory
            )
            contextBlocks.append(charPersonalityBlock)
        }

        // character scenario block
        if let scenario = characterCard.scenario?.replaceChatSequences(user: persona?.name, char: chat.chatTitle), let charScenarioTokens = await getTokenCount(text: scenario) {
            let charScenarioBlock = ContextBlock(
                kind: .characterScenario,
                priority: .required,
                text: scenario,
                tokenCount: charScenarioTokens,
                target: .memory
            )
            contextBlocks.append(charScenarioBlock)
        }

        // character message example block
        if let messageExample = characterCard.messageExample?.replaceChatSequences(user: persona?.name, char: chat.chatTitle), let charMessageExampleTokens = await getTokenCount(text: messageExample) {
            let charMessageExampleBlock = ContextBlock(
                kind: .characterMessageExample,
                priority: .low,
                text: messageExample,
                tokenCount: charMessageExampleTokens,
                target: .memory
            )
            contextBlocks.append(charMessageExampleBlock)
        }

        // character sys prompt block
        if let charSysPrompt = characterCard.systemPrompt?.replaceChatSequences(user: persona?.name, char: chat.chatTitle), let charSysPromptTokens = await getTokenCount(text: charSysPrompt) {
            let charSysPromptBlock = ContextBlock(
                kind: .characterSysPromp,
                priority: .low,
                text: charSysPrompt,
                tokenCount: charSysPromptTokens,
                target: .memory
            )
            contextBlocks.append(charSysPromptBlock)
        }
        
    }
    private func buildMemoryBlocks() async {
        let persona = await ServiceContainer.shared.getPersona
        let personaName = persona?.name
        
        // System Promp / Templates 
        let templates = await settings.connectionSettings.userTemplates.values
            .filter(\.isEnabled)
            .map(\.content)
            .joined(separator: "\n")
            .replaceChatSequences(user: personaName, char: chat.chatTitle)

        if let templatesTokens = await getTokenCount(text: templates) {
            let templatesBlock = ContextBlock(
                kind: .system,
                priority: .required,
                text: templates,
                tokenCount: templatesTokens,
                target: .memory
            )
            contextBlocks.append(templatesBlock)
        }

        // User Memory Injected Notes
        var notes = chat.chatNotes.filter {
            $0.injectInMemory
        }.compactMap(\.note).joined(separator: "\n")
        .replaceChatSequences(user: personaName, char: chat.chatTitle)

        notes = "[Story Notes]\n\(notes)" 
        if let notesTokens = await getTokenCount(text: notes) {
            let notesBlock = ContextBlock(
                kind: .userNote,
                priority: .high,
                text: notes,
                tokenCount: notesTokens,
                target: .memory
            )
            contextBlocks.append(notesBlock)
        }

        // Persona 
        let personalDescription = persona?.description?.replaceChatSequences(user: personaName, char: chat.chatTitle)
        if let personalDescription = personalDescription, let personaTokens = await getTokenCount(text: personalDescription) {
            let personaBlock = ContextBlock(
                kind: .persona,
                priority: .high,
                text: personalDescription,
                tokenCount: personaTokens,
                target: .memory
            )
            contextBlocks.append(personaBlock)
        }
    }
    
    private func buildMessageBlocks(
        continued: Bool = false,
        forceThinking: Bool = false 
    ) async {
        let connectionSettings = await settings.connectionSettings
        let persona = await ServiceContainer.shared.getPersona
        let personaName = persona?.name

        let messages = chat.messages
        let lastUserID = messages.last(where: { $0.actor == .user })?.id
        let firstBotIdD = messages.first(where: { $0.actor == .bot })?.id

        for (index, message) in messages.enumerated() {
            guard message.exclude == false else {
                continue
            }

            // order multiplied by 10 to allow note injection
            let orderIndex = 1000 + (index * 10)
            if var noteBlock = await noteInjectorBlock(
                settings: connectionSettings,
                personaName: personaName,
                messageIndex: index
            ) {
                noteBlock.order = orderIndex - 1
                contextBlocks.append(noteBlock)
            }

            guard var messageBlock = await renderMessageBlock(
                message: message,
                settings: connectionSettings,
                personaName: personaName,
                lastUserID: lastUserID,
                firstBotID: firstBotIdD,
                continueResponse: continued,
                forceThinking: forceThinking 
            ) else {
                continue 
            }

            messageBlock.order = orderIndex
            contextBlocks.append(messageBlock)
        }
    }

    private func noteInjectorBlock(
        settings: ConnectionSettingsModel, 
        personaName: String?,
        messageIndex: Int
    ) async -> ContextBlock? {
        guard let note = chat.chatNotes.first(where: {
            let indexToInject = max(0, chat.messages.count - $0.depth)
            return indexToInject == messageIndex && $0.injectInMemory == false
        })?.note else {
            return nil
        }

        let renderedText = "\(settings.systemStopSequence)\n\(note.replaceChatSequences(user: personaName, char: chat.chatTitle))\n"

        guard let tokens = await getTokenCount(text: renderedText) else {
            return nil
        }

        return ContextBlock(
            kind: .userNote,
            priority: .high,
            text: renderedText,
            tokenCount: tokens,
            target: .prompt
        )
    }

    private func renderMessageBlock(
        message: MessageModel,
        settings: ConnectionSettingsModel,
        personaName: String?,
        lastUserID: UUID?, 
        firstBotID: UUID?,
        continueResponse: Bool,
        forceThinking: Bool,
    ) async -> ContextBlock? {
        let messageText = message.text
            .replaceChatSequences(user: personaName, char: chat.chatTitle)

        let renderedText: String

        switch message.actor {
            case .user:
                var text = "\(messageText)\(settings.botStopSequence)"

                if settings.botStopSequence.isEmpty == false {
                    text += " "
                }

                if forceThinking && message.id == lastUserID {
                    text += "\(settings.thinkingStartSequence)\n\(settings.forceThinkingInstruct)"
                }

                renderedText = text
            case .bot: 
                guard message.status == .done || continueResponse else {
                    return nil
                }

                let prefix = firstBotID == message.id ? settings.botStopSequence : ""
                let suffix = continueResponse ? "" : settings.userStopSequence

                renderedText = "\(prefix)\(messageText)\(suffix)"
        }

        guard let tokens = await getTokenCount(text: renderedText) else {
            return nil
        }

        return ContextBlock(
            kind: .message, 
            priority: .high,
            text: renderedText,
            tokenCount: tokens,
            target: .prompt
        )
    }
}

// TokenCount cache 
final class TokenCountCache {
    private var cache: [String: Int] = [:]

    func count(_ text: String, tokenizer: CoreBPE) -> Int {
        if let cached = cache[text] {
            return cached
        }

        let count = tokenizer.encodeWithSpecialTokens(text: text).count
        cache[text] = count
        return count
    }

    func clear() {
        cache.removeAll()
    }
}

// MARK: - Prompt Builders 
// struct TextCompletionContextBuilder {
//     func render(
//         memoryBlocks: [ContextBlock],
//         promptBlocks: [ContextBlock],
//         settings: ConnectionSettingsModel,
//         contiued: Bool = false, 
//         forceThinking: Bool = false
//     ) -> TextCompletionContent{
        
//     }
// }

// struct ChatCompletionContextBuilder {
//     func renderOpenAI(
//         memoryBlocks: [ContextBlock],
//         promptBlocks: [ContextBlock],
//         continued: Bool = false
//     ) -> ChatCompletionContent {
        
//     }
// }