import Foundation

struct StreamAccumulator {
    private let originalText: String
    private let continuationSeparator: String
    private var generatedText = ""

    init(originalText: String = "", continuationSeparator: String = "") {
        self.originalText = originalText
        self.continuationSeparator = continuationSeparator
    }

    mutating func ingest(_ incomingText: String) -> String {
        guard incomingText.isEmpty == false else {
            return generatedText
        }

        if incomingText.hasPrefix(generatedText) {
            generatedText = incomingText
        } else {
            generatedText += incomingText
        }

        return generatedText
    }

    func combinedVisibleText(_ visibleGeneratedText: String) -> String {
        guard originalText.isEmpty == false else {
            return visibleGeneratedText
        }

        guard visibleGeneratedText.isEmpty == false else {
            return originalText
        }

        return originalText + continuationSeparator + visibleGeneratedText
    }
}

struct ReasoningParseResult {
    let visibleText: String
    let shouldShowThinking: Bool
}

struct ReasoningStreamParser {
    private enum State {
        case notStarted
        case insideReasoning
        case visibleAnswer
        case malformedReasoning
    }

    private let startsInsideReasoning: Bool
    private var state: State

    init(startsInsideReasoning: Bool = false) {
        self.startsInsideReasoning = startsInsideReasoning
        self.state = startsInsideReasoning ? .insideReasoning : .notStarted
    }

    mutating func parse(_ rawText: String, isFinal: Bool) -> ReasoningParseResult {
        switch state {
        case .notStarted:
            guard hasOpeningThinkTag(atStartOf: rawText) else {
                state = .visibleAnswer
                return ReasoningParseResult(visibleText: rawText, shouldShowThinking: false)
            }

            if let visibleText = textAfterClosingThinkTag(in: rawText) {
                state = .visibleAnswer
                return ReasoningParseResult(visibleText: visibleText, shouldShowThinking: false)
            }

            if isFinal {
                state = .malformedReasoning
                return ReasoningParseResult(
                    visibleText: textAfterOpeningThinkTag(in: rawText),
                    shouldShowThinking: false
                )
            }

            state = .insideReasoning
            return ReasoningParseResult(visibleText: "", shouldShowThinking: true)

        case .insideReasoning:
            if let visibleText = textAfterClosingThinkTag(in: rawText) {
                state = .visibleAnswer
                return ReasoningParseResult(visibleText: visibleText, shouldShowThinking: false)
            }

            if isFinal {
                state = .malformedReasoning
                return ReasoningParseResult(
                    visibleText: textAfterOpeningThinkTag(in: rawText),
                    shouldShowThinking: false
                )
            }

            return ReasoningParseResult(visibleText: "", shouldShowThinking: true)

        case .visibleAnswer:
            if startsInsideReasoning,
                hasOpeningThinkTag(atStartOf: rawText) == false,
                let visibleText = textAfterClosingThinkTag(in: rawText) {
                return ReasoningParseResult(
                    visibleText: visibleText,
                    shouldShowThinking: false
                )
            }

            return ReasoningParseResult(
                visibleText: ReasoningStreamParser.visibleText(from: rawText),
                shouldShowThinking: false
            )

        case .malformedReasoning:
            return ReasoningParseResult(
                visibleText: textAfterOpeningThinkTag(in: rawText),
                shouldShowThinking: false
            )
        }
    }

    static func visibleText(from rawText: String) -> String {
        if hasOpeningThinkTag(atStartOf: rawText) {
            if let visibleText = textAfterClosingThinkTag(in: rawText) {
                return visibleText
            }

            return textAfterOpeningThinkTag(in: rawText)
        }

        return rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasOpeningThinkTag(atStartOf text: String) -> Bool {
        text.range(
            of: #"^\s*<think\s*>"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func textAfterOpeningThinkTag(in text: String) -> String {
        guard let range = text.range(
            of: #"^\s*<think\s*>"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func textAfterClosingThinkTag(in text: String) -> String? {
        guard let range = text.range(of: "</think>", options: .caseInsensitive) else {
            return nil
        }

        return String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasOpeningThinkTag(atStartOf text: String) -> Bool {
        Self.hasOpeningThinkTag(atStartOf: text)
    }

    private func textAfterOpeningThinkTag(in text: String) -> String {
        Self.textAfterOpeningThinkTag(in: text)
    }

    private func textAfterClosingThinkTag(in text: String) -> String? {
        Self.textAfterClosingThinkTag(in: text)
    }
}
