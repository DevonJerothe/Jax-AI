//
//  PocketAITests.swift
//  PocketAITests
//
//  Created by devon jerothe on 3/11/25.
//

import Foundation
import Testing
@testable import PocketAI

struct PocketAITests {

    @Test func escapedSequencesDecodeToStoredValues() {
        #expect("\\nUser:".decodeEscapedSequence() == "\nUser:")
        #expect("\\tTabbed\\rReturn".decodeEscapedSequence() == "\tTabbed\rReturn")
        #expect("Path\\\\Name".decodeEscapedSequence() == "Path\\Name")
    }

    @Test func unknownAndIncompleteEscapesArePreserved() {
        #expect("literal\\x".decodeEscapedSequence() == "literal\\x")
        #expect("trailing\\".decodeEscapedSequence() == "trailing\\")
    }

    @Test func storedValuesEncodeForTextFields() {
        #expect("\nUser:\t".encodeEscapedSequence() == "\\nUser:\\t")
    }

}

struct InitialMessageGreetingTests {

    private func makeGreetingMessage() -> MessageModel {
        let card = CharacterCardModel(
            name: "Test Card",
            firstMessage: "First mes",
            altGreetings: ["Alt 1", "Alt 2", "Alt 3", "Alt 4"]
        )

        return MessageModel(
            chatId: UUID().uuidString,
            actor: .bot,
            text: card.firstMessage ?? "",
            textGenerationHistory: card.initialGreetingHistory
        )
    }

    @Test func firstMessageIsSeededBeforeAlternateGreetings() {
        let card = CharacterCardModel(
            name: "Test Card",
            firstMessage: "First mes",
            altGreetings: ["Alt 1", "Alt 2", "Alt 3", "Alt 4"]
        )

        let history = card.initialGreetingHistory

        #expect(history.map(\.text) == ["First mes", "Alt 1", "Alt 2", "Alt 3", "Alt 4"])
    }

    @Test func newChatOpensOnFirstMessageAtInitialPosition() {
        let message = makeGreetingMessage()

        #expect(message.generationPosition == 1)
        #expect(message.generationCount == 5)
        #expect(message.hasMoreGenerations(before: true) == false)
        #expect(message.hasMoreGenerations(before: false) == true)
    }

    @Test func forwardNavigationWalksGreetingsInCardOrder() {
        var message = makeGreetingMessage()

        for (offset, greeting) in ["Alt 1", "Alt 2", "Alt 3", "Alt 4"].enumerated() {
            message.nextGeneration()

            #expect(message.text == greeting)
            #expect(message.generationPosition == offset + 2)
        }

        #expect(message.hasMoreGenerations(before: false) == false)
    }

    @Test func backwardNavigationReturnsToFirstMessage() {
        var message = makeGreetingMessage()

        for _ in 0..<4 {
            message.nextGeneration()
        }
        #expect(message.generationPosition == 5)

        message.previousGeneration()
        #expect(message.text == "Alt 3")
        #expect(message.generationPosition == 4)

        message.previousGeneration()
        #expect(message.text == "Alt 2")
        #expect(message.generationPosition == 3)

        for _ in 0..<2 {
            message.previousGeneration()
        }

        #expect(message.text == "First mes")
        #expect(message.generationPosition == 1)
        #expect(message.hasMoreGenerations(before: true) == false)
    }

    @Test func regeneratingInitialMessageDoesNotDuplicateItInHistory() {
        var message = makeGreetingMessage()

        message.addNewGeneration()

        #expect(message.textGenerationHistory.count == 5)
        #expect(message.textGenerationHistory.filter { $0.text == "First mes" }.count == 1)
    }

    @Test func cardsWithoutAlternateGreetingsHaveNoGreetingHistory() {
        let card = CharacterCardModel(name: "Test Card", firstMessage: "First mes")

        #expect(card.initialGreetingHistory.isEmpty)

        let message = MessageModel(
            chatId: UUID().uuidString,
            actor: .bot,
            text: card.firstMessage ?? "",
            textGenerationHistory: card.initialGreetingHistory
        )

        // No navigator should be shown when there is nothing to navigate.
        #expect(message.generationPosition == nil)
    }

}
