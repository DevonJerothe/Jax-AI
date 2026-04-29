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
    private let thinkingStartSequence: String
    private let thinkingStopSequence: String
    private var state: State

    init(
        startsInsideReasoning: Bool = false,
        thinkingStartSequence: String = ConnectionSettingsModel.defaultThinkingStartSequence,
        thinkingStopSequence: String = ConnectionSettingsModel.defaultThinkingStopSequence
    ) {
        self.startsInsideReasoning = startsInsideReasoning
        self.thinkingStartSequence = thinkingStartSequence
        self.thinkingStopSequence = thinkingStopSequence
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
                visibleText: ReasoningStreamParser.visibleText(
                    from: rawText,
                    thinkingStartSequence: thinkingStartSequence,
                    thinkingStopSequence: thinkingStopSequence
                ),
                shouldShowThinking: false
            )

        case .malformedReasoning:
            return ReasoningParseResult(
                visibleText: textAfterOpeningThinkTag(in: rawText),
                shouldShowThinking: false
            )
        }
    }

    static func visibleText(
        from rawText: String,
        thinkingStartSequence: String = ConnectionSettingsModel.defaultThinkingStartSequence,
        thinkingStopSequence: String = ConnectionSettingsModel.defaultThinkingStopSequence
    ) -> String {
        if hasOpeningThinkTag(atStartOf: rawText, thinkingStartSequence: thinkingStartSequence) {
            if let visibleText = textAfterClosingThinkTag(
                in: rawText,
                thinkingStopSequence: thinkingStopSequence
            ) {
                return visibleText
            }

            return textAfterOpeningThinkTag(
                in: rawText,
                thinkingStartSequence: thinkingStartSequence
            )
        }

        return rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasOpeningThinkTag(
        atStartOf text: String,
        thinkingStartSequence: String
    ) -> Bool {
        guard thinkingStartSequence.isEmpty == false else {
            return false
        }

        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix(thinkingStartSequence, caseInsensitive: true)
    }

    private static func textAfterOpeningThinkTag(
        in text: String,
        thinkingStartSequence: String
    ) -> String {
        guard thinkingStartSequence.isEmpty == false else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.hasPrefix(thinkingStartSequence, caseInsensitive: true) else {
            return trimmedText
        }

        let upperBound = trimmedText.index(
            trimmedText.startIndex,
            offsetBy: thinkingStartSequence.count
        )
        return String(trimmedText[upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func textAfterClosingThinkTag(
        in text: String,
        thinkingStopSequence: String
    ) -> String? {
        guard thinkingStopSequence.isEmpty == false,
            let range = text.range(of: thinkingStopSequence, options: .caseInsensitive) else {
            return nil
        }

        return String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasOpeningThinkTag(atStartOf text: String) -> Bool {
        Self.hasOpeningThinkTag(atStartOf: text, thinkingStartSequence: thinkingStartSequence)
    }

    private func textAfterOpeningThinkTag(in text: String) -> String {
        Self.textAfterOpeningThinkTag(in: text, thinkingStartSequence: thinkingStartSequence)
    }

    private func textAfterClosingThinkTag(in text: String) -> String? {
        Self.textAfterClosingThinkTag(in: text, thinkingStopSequence: thinkingStopSequence)
    }
}

private extension String {
    func hasPrefix(_ prefix: String, caseInsensitive: Bool) -> Bool {
        guard caseInsensitive else {
            return hasPrefix(prefix)
        }

        return range(
            of: prefix,
            options: [.anchored, .caseInsensitive]
        ) != nil
    }
}
