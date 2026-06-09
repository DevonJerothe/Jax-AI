import Foundation
import SwiftLLMSDK

struct LoreBookContextBuilder {
    private struct Candidate {
        let loreBookIndex: Int
        let entryIndex: Int
        let entry: LoreBookEntryModel
        let renderedContent: String
        let tokenCount: Int

        var order: Int {
            entry.order ?? 0
        }

        var position: LoreBookEntryPosition {
            LoreBookEntryPosition(rawValue: entry.position)
        }
    }

    func buildBlocks(
        loreBooks: [LoreBookModel],
        chat: ChatModel,
        personaName: String?,
        getTokenCount: (String?) async -> Int?
    ) async -> [ContextBlock] {
        guard loreBooks.isEmpty == false else {
            return []
        }

        let visibleMessages = chat.messages.enumerated().filter { _, message in
            message.exclude == false
        }

        var blocks: [ContextBlock] = []
        for (loreBookIndex, loreBook) in loreBooks.enumerated() {
            let scanText = scanText(
                for: loreBook,
                visibleMessages: visibleMessages,
                chatTitle: chat.chatTitle,
                personaName: personaName
            )

            let candidates = await candidates(
                for: loreBook,
                loreBookIndex: loreBookIndex,
                scanText: scanText,
                chatTitle: chat.chatTitle,
                personaName: personaName,
                getTokenCount: getTokenCount
            )

            let selectedCandidates = selectCandidates(
                candidates,
                tokenBudget: loreBook.tokenBudget
            )

            blocks.append(
                contentsOf: selectedCandidates.map {
                    block(
                        for: $0,
                        visibleMessages: visibleMessages
                    )
                }
            )
        }

        return blocks.sorted { lhs, rhs in
            if lhs.target != rhs.target {
                return targetRank(lhs.target) < targetRank(rhs.target)
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            return (lhs.sourceID?.uuidString ?? "") < (rhs.sourceID?.uuidString ?? "")
        }
    }

    private func candidates(
        for loreBook: LoreBookModel,
        loreBookIndex: Int,
        scanText initialScanText: String,
        chatTitle: String,
        personaName: String?,
        getTokenCount: (String?) async -> Int?
    ) async -> [Candidate] {
        var scanText = initialScanText
        var candidatesByID: [UUID: Candidate] = [:]
        var candidates: [Candidate] = []
        let maxPasses = loreBook.recursiveScanning ? 5 : 1

        for _ in 0..<maxPasses {
            var passAddedContent: [String] = []

            for (entryIndex, entry) in loreBook.entries.enumerated() {
                guard candidatesByID[entry.id] == nil else {
                    continue
                }

                guard matches(entry: entry, scanText: scanText) else {
                    continue
                }

                let renderedContent = entry.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replaceChatSequences(user: personaName, char: chatTitle)

                guard renderedContent.isEmpty == false,
                    let tokenCount = await getTokenCount(renderedContent)
                else {
                    continue
                }

                let candidate = Candidate(
                    loreBookIndex: loreBookIndex,
                    entryIndex: entryIndex,
                    entry: entry,
                    renderedContent: renderedContent,
                    tokenCount: tokenCount
                )

                candidatesByID[entry.id] = candidate
                candidates.append(candidate)
                passAddedContent.append(renderedContent)
            }

            guard loreBook.recursiveScanning, passAddedContent.isEmpty == false else {
                break
            }

            scanText += "\n" + passAddedContent.joined(separator: "\n")
        }

        return candidates
    }

    private func scanText(
        for loreBook: LoreBookModel,
        visibleMessages: [(offset: Int, element: MessageModel)],
        chatTitle: String,
        personaName: String?
    ) -> String {
        let scanDepth = max(0, loreBook.scanDepth)
        guard scanDepth > 0 else {
            return ""
        }

        return
            visibleMessages
            .suffix(scanDepth)
            .map { _, message in
                message.text.replaceChatSequences(user: personaName, char: chatTitle)
            }
            .joined(separator: "\n")
    }

    private func matches(entry: LoreBookEntryModel, scanText: String) -> Bool {
        guard entry.enabled ?? true else {
            return false
        }

        guard entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return false
        }

        if entry.constant == true {
            return true
        }

        let primaryKeys = normalizedKeys(entry.keys, caseSensitive: entry.caseSensitive ?? false)
        guard primaryKeys.isEmpty == false else {
            return false
        }

        let normalizedScanText = normalized(scanText, caseSensitive: entry.caseSensitive ?? false)
        guard primaryKeys.contains(where: { normalizedScanText.contains($0) }) else {
            return false
        }

        let secondaryKeys = normalizedKeys(
            entry.secondaryKeys,
            caseSensitive: entry.caseSensitive ?? false
        )
        guard secondaryKeys.isEmpty == false else {
            return true
        }

        return secondaryKeys.contains(where: { normalizedScanText.contains($0) })
    }

    private func normalizedKeys(_ keys: [String], caseSensitive: Bool) -> [String] {
        keys.compactMap { key in
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedKey.isEmpty == false else {
                return nil
            }
            return normalized(trimmedKey, caseSensitive: caseSensitive)
        }
    }

    private func normalized(_ text: String, caseSensitive: Bool) -> String {
        caseSensitive ? text : text.lowercased()
    }

    private func selectCandidates(
        _ candidates: [Candidate],
        tokenBudget: Int?
    ) -> [Candidate] {
        guard let tokenBudget else {
            return candidates.sorted(by: renderSort)
        }

        var remaining = max(0, tokenBudget)
        var selected: [Candidate] = []

        for candidate in candidates.sorted(by: selectionSort) {
            guard candidate.tokenCount <= remaining else {
                continue
            }

            selected.append(candidate)
            remaining -= candidate.tokenCount
        }

        return selected.sorted(by: renderSort)
    }

    private func block(
        for candidate: Candidate,
        visibleMessages: [(offset: Int, element: MessageModel)]
    ) -> ContextBlock {
        let position = candidate.position

        return ContextBlock(
            kind: .loreBook,
            priority: .high,
            text: candidate.renderedContent,
            tokenCount: candidate.tokenCount,
            target: position == .atDepth ? .prompt : .memory,
            order: order(for: candidate, visibleMessages: visibleMessages),
            actor: .system,
            sourceID: candidate.entry.id
        )
    }

    private func order(
        for candidate: Candidate,
        visibleMessages: [(offset: Int, element: MessageModel)]
    ) -> Int {
        switch candidate.position {
        case .beforeChar:
            return ContextMemoryOrder.loreBeforeCharacter + stableEntryOffset(candidate)
        case .afterChar:
            return ContextMemoryOrder.loreAfterCharacter + stableEntryOffset(candidate)
        case .atDepth:
            return ContextPromptOrder.loreAtDepth(
                candidate.entry.depth ?? 0,
                visibleMessageCount: visibleMessages.count
            )
        }
    }

    private func stableEntryOffset(_ candidate: Candidate) -> Int {
        (candidate.loreBookIndex * 10_000) + candidate.entryIndex
    }

    private func selectionSort(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.order != rhs.order {
            return lhs.order > rhs.order
        }
        if lhs.loreBookIndex != rhs.loreBookIndex {
            return lhs.loreBookIndex < rhs.loreBookIndex
        }
        if lhs.entryIndex != rhs.entryIndex {
            return lhs.entryIndex < rhs.entryIndex
        }
        return lhs.entry.id.uuidString < rhs.entry.id.uuidString
    }

    private func renderSort(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        let lhsPosition = positionRank(lhs.position)
        let rhsPosition = positionRank(rhs.position)
        if lhsPosition != rhsPosition {
            return lhsPosition < rhsPosition
        }
        if lhs.loreBookIndex != rhs.loreBookIndex {
            return lhs.loreBookIndex < rhs.loreBookIndex
        }
        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }
        if lhs.entryIndex != rhs.entryIndex {
            return lhs.entryIndex < rhs.entryIndex
        }
        return lhs.entry.id.uuidString < rhs.entry.id.uuidString
    }

    private func positionRank(_ position: LoreBookEntryPosition) -> Int {
        switch position {
        case .beforeChar:
            return 0
        case .afterChar:
            return 1
        case .atDepth:
            return 2
        }
    }

    private func targetRank(_ target: ContextBlock.Target) -> Int {
        switch target {
        case .memory:
            return 0
        case .prompt:
            return 1
        }
    }
}
