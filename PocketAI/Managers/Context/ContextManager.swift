import Foundation
import SwiftLLMSDK
import SwiftTiktoken

// We should build a context manager for each chat instance. This should handle all token counting and
// budgeting as we continue chatting with the bot
final class ContextManager {
    private(set) var settings: ConnectionSettingsModel
    private(set) var chat: ChatModel

    private var tokenizer: CoreBPE?
    private var tokenCache: TokenCountCache = .init()
    var contextBlocks: [ContextBlock] = []

    private var loreBookContextBuilder: LoreBookContextBuilder = .init()
    private var textCompletionBuilder: TextCompletionContextBuilder = .init()
    private var chatCompletionBuilder: ChatCompletionContextBuilder = .init()

    init(
        from chat: ChatModel,
        _ settings: ConnectionSettingsModel
    ) {
        self.settings = settings
        self.chat = chat
    }

    func prepare() async {
        await loadTokenizerIfNeeded()
        await self.loadContextFromChat()
        await refreshLoreBookBlocks()
    }

    public func buildContext(
        chat: ChatModel,
        reloadContext: Bool = true,
        continued: Bool = false,
        forceThinking: Bool = false
    ) async -> ContextOutput? {

        await loadTokenizerIfNeeded()

        guard let tokenizer = tokenizer else {
            return .error("Tokenizer not found")
        }

        self.chat = chat
        let connectionType = settings.connectionType

        if reloadContext {
            contextBlocks.removeAll()
            await loadContextFromChat()
            await refreshLoreBookBlocks()
            await buildMessageBlocks(continued: continued)
        }

        switch connectionType {
        case .KoboldAPI:
            return .textCompletion(
                textCompletionBuilder.render(
                    memoryBlocks: contextBlocks.filter { $0.target == .memory },
                    promptBlocks: contextBlocks.filter { $0.target == .prompt },
                    settings: settings,
                    continued: continued,
                    forceThinking: forceThinking,
                    tokenizer: tokenizer
                )
            )
        case .OpenRouter:
            return .chatCompletion(
                chatCompletionBuilder.render(
                    memoryBlocks: contextBlocks.filter { $0.target == .memory },
                    promptBlocks: contextBlocks.filter { $0.target == .prompt },
                    settings: settings,
                    continued: continued,
                    forceThinking: forceThinking,
                    tokenizer: tokenizer
                )
            )
        }
    }

    private func loadContextFromChat() async {
        guard let characterCard = chat.characterCards.first else {
            print("No CharacterFound")
            return
        }

        // character blocks
        await buildCharacterBlocks(characterCard)
        // system prompts and other memory blocks
        await buildMemoryBlocks()
    }

    private func loadTokenizerIfNeeded() async {
        guard tokenizer == nil else {
            return
        }

        if let sharedTokenizer = await ServiceContainer.shared.tokenizer {
            tokenizer = sharedTokenizer
            return
        }

        tokenizer = try? await CoreBPE.cl100kBase()
    }

    public func refreshMemory(chat: ChatModel) async {
        self.chat = chat
        contextBlocks.removeAll {
            $0.target == .memory
        }

        await loadContextFromChat()
        await refreshLoreBookBlocks()
    }

    public func refreshMessageBlocks(chat: ChatModel) async {
        self.chat = chat
        contextBlocks.removeAll {
            $0.target == .prompt
        }

        await buildMessageBlocks()
        await refreshLoreBookBlocks()
    }

    public func updateMessageBlock(message: MessageModel, new: Bool = false) async {
        let personaName = await ServiceContainer.shared.getPersona?.name

        // Treat as a new message
        if new {
            // If the caller has not yet inserted the new message into chat.messages, place it after
            // the current visible messages.
            let nextVisibleIndex = chat.messages.filter { $0.exclude == false }.count

            if var messageBlock = await buildMessageBlock(
                message: message,
                personaName: personaName,
                continueResponse: false
            ) {
                messageBlock.order = ContextPromptOrder.message(index: nextVisibleIndex)
                contextBlocks.append(messageBlock)
            }

            await refreshLoreBookBlocks()
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

            await refreshLoreBookBlocks()
        }
    }

    func getTokenCount(text: String?) async -> Int? {
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

    func syncSettigns(_ settings: ConnectionSettingsModel) {
        self.settings = settings
    }

    private func refreshLoreBookBlocks() async {
        contextBlocks.removeAll {
            $0.kind == .loreBook
        }

        let personaName = await ServiceContainer.shared.getPersona?.name
        let loreBookBlocks = await loreBookContextBuilder.buildBlocks(
            loreBooks: chat.loreBooks,
            chat: chat,
            personaName: personaName,
            getTokenCount: getTokenCount
        )

        contextBlocks.append(contentsOf: loreBookBlocks)
    }
}
