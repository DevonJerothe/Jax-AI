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
    var actor: OpenRouterMessageRole
    let sourceID: UUID? 

    init(
        kind: Kind,
        priority: Priority,
        text: String,
        tokenCount: Int,
        target: Target,
        order: Int = 0, // Order is mostly used for prompt target. So we can leave 0 as default for others. 
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

// We should build a context manager for each chat instance. This should handle all token counting and 
// budgeting as we continue chatting with the bot
final class ContextManager {
    enum ContextOutput {
        case textCompletion(TextCompletionContent)
        case chatCompletion(ChatCompletionContent)
        case error(String)
    }
    
    private(set) var settings: ConnectionStatusManager
    private(set) var chat: ChatModel
    
    private var tokenizer: CoreBPE?
    private var tokenCache: TokenCountCache = .init()
    private var contextBlocks: [ContextBlock] = []

    private var textCompletionBuilder: TextCompletionContextBuilder = .init()
    
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

    public func buildContext(
        chat: ChatModel,
        reloadContext: Bool = true, 
        continued: Bool = false, 
        forceThinking: Bool = false
    ) async -> ContextOutput? {

        // replace with eror type
        guard let tokenizer = tokenizer else {
            return .error("Tokenizer not found")
        }
        
        self.chat = chat 
        let connectionType = await settings.connectionSettings.connectionType

        if reloadContext {
            contextBlocks.removeAll()
            await loadContextFromChat()
            await buildMessageBlocks()
        }

        switch connectionType {
            case .KoboldAPI:
                return .textCompletion(await textCompletionBuilder.render(
                    memoryBlocks: contextBlocks.filter { $0.target == .memory }, 
                    promptBlocks: contextBlocks.filter { $0.target == .prompt }, 
                    settings: settings.connectionSettings, 
                    continued: continued, 
                    forceThinking: forceThinking, 
                    tokenizer: tokenizer
                ))
            case .OpenRouter: 

                // TODO: support OpenRouter after Kobold Testing
                return .error("OpenRouter WIP")
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

    public func refreshMemory(chat: ChatModel) async {
        self.chat = chat
        contextBlocks.removeAll {
            $0.target == .memory
        }

        await loadContextFromChat()
    }

    public func refreshMessageBlocks(chat: ChatModel) async {
        self.chat = chat
        contextBlocks.removeAll {
            $0.target == .prompt
        }

        await buildMessageBlocks()
    }

    public func updateMessageBlock(message: MessageModel, new: Bool = false) async {
        let personaName = await ServiceContainer.shared.getPersona?.name

        // Treat as a new message 
        if new {
            // get last index of current message list 
            let lastIndex = chat.messages.count
            
            if var messageBlock = await buildMessageBlock(
                message: message, 
                personaName: personaName, 
                continueResponse: false
            ) {
                messageBlock.order = 1000 + (lastIndex * 10) // normal loop index starts at 0, count starts at 1. 
                contextBlocks.append(messageBlock)
            }
        } else {
            // find contextBlock to update 
            let oldBlock = contextBlocks.first {
                $0.sourceID == message.id
            }
            guard let oldBlock = oldBlock else { return }

            contextBlocks.removeAll { $0.sourceID == message.id }
            if var updatedBlock = await buildMessageBlock(
                message: message, 
                personaName: personaName, 
                continueResponse: false
            ) {
                updatedBlock.order = oldBlock.order
                contextBlocks.append(updatedBlock)
            }
        }
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
        let notes = chat.chatNotes.filter {
            $0.injectInMemory
        }.compactMap(\.note).joined(separator: "\n")
        .replaceChatSequences(user: personaName, char: chat.chatTitle)
 
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

            guard var messageBlock = await buildMessageBlock(
                message: message,
                personaName: personaName,
                continueResponse: continued,
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

        let renderedText = note.replaceChatSequences(user: personaName, char: chat.chatTitle)

        guard let tokens = await getTokenCount(text: renderedText) else {
            return nil
        }

        return ContextBlock(
            kind: .userNote,
            priority: .high,
            text: renderedText,
            tokenCount: tokens,
            target: .prompt,
            actor: .system
        )
    }

    private func buildMessageBlock(
        message: MessageModel,
        personaName: String?,
        continueResponse: Bool,
    ) async -> ContextBlock? {
        let messageText = message.text
            .replaceChatSequences(user: personaName, char: chat.chatTitle)

        guard message.actor == .user || message.status == .done || continueResponse else {
            return nil
        }

        guard let tokens = await getTokenCount(text: messageText) else {
            return nil
        }

        return ContextBlock(
            kind: .message, 
            priority: .high,
            text: messageText,
            tokenCount: tokens,
            target: .prompt,
            actor: message.actor == .user ? .user : .assistant,
            sourceID: message.id
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
    ) -> TextCompletionContent{

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
                availableContextTokens: availableContextTokens - selectedMemoryTokens - selectedPromptTokens, 
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
            renderedBlocks.append(RenderedContextBlock(
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
        let firstBotMessagedID = sortedBlocks.first(where: { $0.actor == .assistant && $0.kind == .message })?.sourceID
        let lastUserMessageID = sortedBlocks.last(where: { $0.actor == .user && $0.kind == .message })?.sourceID

        var renderedBlocks: [RenderedContextBlock] = []

        for block in sortedBlocks {
            var renderedText = ""
            switch block.actor {
                case .system:
                    renderedText = "\(settings.systemStopSequence)\n\(block.text)"
                case .assistant: 
                    let prefix = block.sourceID == firstBotMessagedID
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
        let requiredBlocks = blocks.filter { $0.priority == .required }.sorted(by: RenderedContextBlock.sort)
        for block in requiredBlocks {
            selected.append(block)
            remaining -= block.tokenCount
        }

        let nonRequiredBlocks = blocks.filter { $0.priority != .required }.sorted(by: RenderedContextBlock.sort)
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

// struct ChatCompletionContextBuilder {
//     func renderOpenAI(
//         memoryBlocks: [ContextBlock],
//         promptBlocks: [ContextBlock],
//         continued: Bool = false
//     ) -> ChatCompletionContent {
        
//     }
// }