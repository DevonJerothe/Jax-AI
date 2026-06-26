//
//  ChatMarkdownStreamSource.swift
//  PocketAI
//
//  Created by Codex on 6/23/26.
//

import Foundation
import SwiftStreamingMarkdown

@MainActor
final class ChatMarkdownStreamSource: StreamedMarkdownSource {
    private let continuation: AsyncStream<String>.Continuation

    let text: AsyncStream<String>

    init() {
        var continuation: AsyncStream<String>.Continuation!
        text = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    func yieldSnapshot(_ markdown: String) {
        continuation.yield(markdown)
    }

    func finish() {
        continuation.finish()
    }
}
