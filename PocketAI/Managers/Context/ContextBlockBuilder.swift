import Foundation

extension ContextManager {
    func buildCharacterBlocks(_ characterCard: CharacterCardModel) async {
        let persona = await ServiceContainer.shared.getPersona

        if let description = characterCard.description?.replaceChatSequences(
            user: persona?.name, char: chat.chatTitle),
            let charDescriptionTokens = await getTokenCount(text: description)
        {
            let charDescriptionBlock = ContextBlock(
                kind: .characterDescription,
                priority: .required,
                text: description,
                tokenCount: charDescriptionTokens,
                target: .memory,
                order: ContextMemoryOrder.characterDescription
            )
            contextBlocks.append(charDescriptionBlock)
        }

        // character personality block
        if let personality = characterCard.personality?.replaceChatSequences(
            user: persona?.name, char: chat.chatTitle),
            let charPersonalityTokens = await getTokenCount(text: personality)
        {
            let charPersonalityBlock = ContextBlock(
                kind: .characterPersonality,
                priority: .required,
                text: personality,
                tokenCount: charPersonalityTokens,
                target: .memory,
                order: ContextMemoryOrder.characterPersonality
            )
            contextBlocks.append(charPersonalityBlock)
        }

        // character scenario block
        if let scenario = characterCard.scenario?.replaceChatSequences(
            user: persona?.name, char: chat.chatTitle),
            let charScenarioTokens = await getTokenCount(text: scenario)
        {
            let charScenarioBlock = ContextBlock(
                kind: .characterScenario,
                priority: .required,
                text: scenario,
                tokenCount: charScenarioTokens,
                target: .memory,
                order: ContextMemoryOrder.characterScenario
            )
            contextBlocks.append(charScenarioBlock)
        }

        // character message example block
        if let messageExample = characterCard.messageExample?.replaceChatSequences(
            user: persona?.name, char: chat.chatTitle),
            let charMessageExampleTokens = await getTokenCount(text: messageExample)
        {
            let charMessageExampleBlock = ContextBlock(
                kind: .characterMessageExample,
                priority: .low,
                text: messageExample,
                tokenCount: charMessageExampleTokens,
                target: .memory,
                order: ContextMemoryOrder.characterMessageExample
            )
            contextBlocks.append(charMessageExampleBlock)
        }

        // character sys prompt block
        if let charSysPrompt = characterCard.systemPrompt?.replaceChatSequences(
            user: persona?.name, char: chat.chatTitle),
            let charSysPromptTokens = await getTokenCount(text: charSysPrompt)
        {
            let charSysPromptBlock = ContextBlock(
                kind: .characterSysPrompt,
                priority: .low,
                text: charSysPrompt,
                tokenCount: charSysPromptTokens,
                target: .memory,
                order: ContextMemoryOrder.characterSystemPrompt
            )
            contextBlocks.append(charSysPromptBlock)
        }

    }

    func buildMemoryBlocks() async {
        let persona = await ServiceContainer.shared.getPersona
        let personaName = persona?.name

        // System Promp / Templates
        // Only attach templates if our chat is not that of a quick chat 
        let isQuickChat = chat.isQuickChat
        let templates = isQuickChat ? "" : settings.userTemplates.values
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
                target: .memory,
                order: ContextMemoryOrder.system
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
                target: .memory,
                order: ContextMemoryOrder.userNote
            )
            contextBlocks.append(notesBlock)
        }

        // Persona
        let personalDescription = persona?.description?.replaceChatSequences(
            user: personaName, char: chat.chatTitle)
        if let personalDescription = personalDescription,
            let personaTokens = await getTokenCount(text: personalDescription)
        {
            let personaBlock = ContextBlock(
                kind: .persona,
                priority: .high,
                text: personalDescription,
                tokenCount: personaTokens,
                target: .memory,
                order: ContextMemoryOrder.persona
            )
            contextBlocks.append(personaBlock)
        }
    }

    func buildMessageBlocks(
        continued: Bool = false
    ) async {
        let persona = await ServiceContainer.shared.getPersona
        let personaName = persona?.name

        let visibleMessages = chat.messages.filter { $0.exclude == false }
        let visibleMessageCount = visibleMessages.count

        for (index, message) in visibleMessages.enumerated() {
            if var noteBlock = await noteInjectorBlock(
                personaName: personaName,
                insertionIndex: index,
                visibleMessageCount: visibleMessageCount
            ) {
                noteBlock.order = ContextPromptOrder.noteBeforeMessage(index: index)
                contextBlocks.append(noteBlock)
            }

            guard
                var messageBlock = await buildMessageBlock(
                    message: message,
                    personaName: personaName,
                    continueResponse: continued,
                )
            else {
                continue
            }

            messageBlock.order = ContextPromptOrder.message(index: index)
            contextBlocks.append(messageBlock)
        }

        if var noteBlock = await noteInjectorBlock(
            personaName: personaName,
            insertionIndex: visibleMessageCount,
            visibleMessageCount: visibleMessageCount
        ) {
            noteBlock.order = ContextPromptOrder.noteAtDepth(
                0, visibleMessageCount: visibleMessageCount)
            contextBlocks.append(noteBlock)
        }
    }

    func noteInjectorBlock(
        personaName: String?,
        insertionIndex: Int,
        visibleMessageCount: Int
    ) async -> ContextBlock? {
        guard
            let note = chat.chatNotes.first(where: {
                let noteInsertionIndex = ContextPromptOrder.insertionIndex(
                    depth: $0.depth,
                    visibleMessageCount: visibleMessageCount
                )
                return noteInsertionIndex == insertionIndex && $0.injectInMemory == false
            })?.note
        else {
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

    func buildMessageBlock(
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
