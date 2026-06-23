//
//  ChatPerformanceInstrumentation.swift
//  PocketAI
//
//  Debug-only probes for measuring chat transcript invalidation.
//

import Foundation
import OSLog

@MainActor
enum ChatPerformanceInstrumentation {
    #if DEBUG
    private static let subsystem = Bundle.main.bundleIdentifier ?? "PocketAI"
    private static let logger = Logger(subsystem: subsystem, category: "ChatPerformance")
    private static let signposter = OSSignposter(logger: logger)
    private static let signpostID = signposter.makeSignpostID()

    private static var chatViewBodyCount = 0
    private static var bubbleBodyCounts: [UUID: Int] = [:]
    private static var markdownRenderCounts: [UUID: Int] = [:]
    private static var streamingUpdateCount = 0

    static func chatViewBody(
        chatID: UUID,
        messageCount: Int,
        streamingMessageID: UUID?,
        chatStatus: ChatStatus
    ) {
        chatViewBodyCount += 1
        signposter.emitEvent("ChatView.body", id: signpostID)
        logger.debug(
            "ChatView body #\(chatViewBodyCount, privacy: .public) chat=\(chatID.uuidString, privacy: .public) messages=\(messageCount, privacy: .public) status=\(String(describing: chatStatus), privacy: .public) streaming=\(streamingMessageID?.uuidString ?? "nil", privacy: .public)"
        )
    }

    static func chatBubbleBody(
        message: MessageModel,
        isStreaming: Bool,
        showToolbar: Bool,
        isEditing: Bool
    ) {
        let count = (bubbleBodyCounts[message.id] ?? 0) + 1
        bubbleBodyCounts[message.id] = count
        signposter.emitEvent("ChatBubbleView.body", id: signpostID)
        logger.debug(
            "ChatBubble body #\(count, privacy: .public) id=\(message.id.uuidString, privacy: .public) actor=\(String(describing: message.actor), privacy: .public) status=\(String(describing: message.status), privacy: .public) streaming=\(isStreaming, privacy: .public) toolbar=\(showToolbar, privacy: .public) editing=\(isEditing, privacy: .public) textHash=\(message.text.hashValue, privacy: .public) textLength=\(message.text.count, privacy: .public)"
        )
    }

    static func markdownRender(
        messageID: UUID,
        actor: MessageActor,
        source: MarkdownRenderSource,
        textLength: Int,
        textHash: Int
    ) {
        let count = (markdownRenderCounts[messageID] ?? 0) + 1
        markdownRenderCounts[messageID] = count
        signposter.emitEvent("ChatBubbleView.markdownRender", id: signpostID)
        logger.debug(
            "Markdown render #\(count, privacy: .public) id=\(messageID.uuidString, privacy: .public) actor=\(String(describing: actor), privacy: .public) source=\(source.rawValue, privacy: .public) textHash=\(textHash, privacy: .public) textLength=\(textLength, privacy: .public)"
        )
    }

    static func streamingUpdate(
        messageID: UUID,
        responseLength: Int,
        deltaLength: Int,
        isFinal: Bool,
        shouldShowThinking: Bool,
        willUpdateStore: Bool
    ) {
        streamingUpdateCount += 1
        signposter.emitEvent("ChatViewModel.streamingUpdate", id: signpostID)
        logger.debug(
            "Streaming update #\(streamingUpdateCount, privacy: .public) id=\(messageID.uuidString, privacy: .public) responseLength=\(responseLength, privacy: .public) deltaLength=\(deltaLength, privacy: .public) final=\(isFinal, privacy: .public) thinking=\(shouldShowThinking, privacy: .public) updatesStore=\(willUpdateStore, privacy: .public)"
        )
    }
    #else
    static func chatViewBody(
        chatID: UUID,
        messageCount: Int,
        streamingMessageID: UUID?,
        chatStatus: ChatStatus
    ) {}

    static func chatBubbleBody(
        message: MessageModel,
        isStreaming: Bool,
        showToolbar: Bool,
        isEditing: Bool
    ) {}

    static func markdownRender(
        messageID: UUID,
        actor: MessageActor,
        source: MarkdownRenderSource,
        textLength: Int,
        textHash: Int
    ) {}

    static func streamingUpdate(
        messageID: UUID,
        responseLength: Int,
        deltaLength: Int,
        isFinal: Bool,
        shouldShowThinking: Bool,
        willUpdateStore: Bool
    ) {}
    #endif
}

enum MarkdownRenderSource: String {
    case streamingBlocks
    case completedString
    case userString
}
