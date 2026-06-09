//
//  PocketAITests.swift
//  PocketAITests
//
//  Created by devon jerothe on 3/11/25.
//

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
