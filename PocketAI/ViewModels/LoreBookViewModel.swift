import Foundation
import SwiftUI

@MainActor
@Observable
final class LoreBookViewModel {
    private let loreBookStore: LoreBookStore
    private let connectionManager: ConnectionStatusManager

    var loreBookSearchText = ""
    var entrySearchText = ""
    var selectedEntryID: UUID?
    var tokenBudgetText = ""
    var errorMessage: String?

    var loreBook: LoreBookModel = LoreBookModel(name: "", description: nil, scanDepth: 2)

    init(loreBookStore: LoreBookStore? = nil, connectionManager: ConnectionStatusManager? = nil) {
        self.loreBookStore = loreBookStore ?? ServiceContainer.shared.getLoreBookStore()
        self.connectionManager =
            connectionManager ?? ServiceContainer.shared.getConnectionStatusManager()
    }

    var loreBooks: [LoreBookModel] {
        guard connectionManager.connectionSettings.locked else {
            return loreBookStore.loreBooks
        }

        return loreBookStore.loreBooks.filter { !$0.isPrivate }
    }

    var filteredLoreBooks: [LoreBookModel] {
        let query = loreBookSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return loreBooks
        }

        return loreBooks.filter { loreBook in
            loreBook.name.localizedCaseInsensitiveContains(query)
                || (loreBook.description?.localizedCaseInsensitiveContains(query) ?? false)
                || loreBook.entries.contains { entry in
                    entry.name.localizedCaseInsensitiveContains(query)
                        || entry.keys.contains { $0.localizedCaseInsensitiveContains(query) }
                        || entry.content.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var filteredEntries: [LoreBookEntryModel] {
        let query = entrySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return loreBook.entries
        }

        return loreBook.entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query)
                || entry.keys.contains { $0.localizedCaseInsensitiveContains(query) }
                || entry.secondaryKeys.contains { $0.localizedCaseInsensitiveContains(query) }
                || entry.content.localizedCaseInsensitiveContains(query)
        }
    }

    var shouldHidePrivateContent: Bool {
        connectionManager.connectionSettings.locked && loreBook.isPrivate
    }

    var selectedEntryBinding: Binding<LoreBookEntryModel?> {
        Binding {
            guard let selectedEntryID = self.selectedEntryID else { return nil }
            return self.loreBook.entries.first(where: { $0.id == selectedEntryID })
        } set: { entry in
            self.selectedEntryID = entry?.id
        }
    }

    func loadLoreBook(withID loreBookID: UUID?) {
        entrySearchText = ""
        selectedEntryID = nil

        guard let loreBookID, let storedLoreBook = loreBookStore.loreBook(withID: loreBookID) else {
            loreBook = LoreBookModel(name: "", description: nil, scanDepth: 2)
            tokenBudgetText = ""
            return
        }

        loreBook = storedLoreBook
        tokenBudgetText = storedLoreBook.tokenBudget.map(String.init) ?? ""
    }

    func deleteLoreBook(loreBook: LoreBookModel) async {
        do {
            try await loreBookStore.deleteLoreBook(loreBook)
        } catch {
            errorMessage = "Failed to delete lorebook."
            print(error)
        }
    }

    func loreBook(withID loreBookID: UUID) -> LoreBookModel? {
        loreBookStore.loreBook(withID: loreBookID)
    }

    func saveLoreBook() async throws {
        let loreBook = normalizedLoreBookForSaving()
        try await loreBookStore.saveLoreBook(loreBook)
        self.loreBook = loreBook
    }

    func saveLoreBook(_ loreBook: LoreBookModel) async throws {
        try await loreBookStore.saveLoreBook(loreBook)
    }

    func addEntry() {
        var entry = LoreBookEntryModel(
            loreBookId: loreBook.id.uuidString,
            name: "New Entry",
            enabled: true,
            keys: [],
            secondaryKeys: [],
            content: "",
            constant: false,
            order: loreBook.entries.count,
            position: 0,
            caseSensitive: false,
            depth: 0
        )
        entry.id = UUID()
        loreBook.entries.append(entry)
        selectedEntryID = entry.id
    }

    func deleteEntry(_ entryID: UUID) {
        loreBook.entries.removeAll { $0.id == entryID }
    }

    func entryEnabledBinding(for entryID: UUID) -> Binding<Bool> {
        Binding {
            self.loreBook.entries.first(where: { $0.id == entryID })?.enabled ?? true
        } set: { value in
            guard let index = self.loreBook.entries.firstIndex(where: { $0.id == entryID }) else {
                return
            }
            self.loreBook.entries[index].enabled = value
        }
    }

    func entryBinding(for entryID: UUID) -> Binding<LoreBookEntryModel>? {
        guard loreBook.entries.contains(where: { $0.id == entryID }) else {
            return nil
        }

        return Binding {
            self.loreBook.entries.first(where: { $0.id == entryID })!
        } set: { value in
            guard let index = self.loreBook.entries.firstIndex(where: { $0.id == entryID }) else {
                return
            }
            self.loreBook.entries[index] = value
        }
    }

    private func normalizedLoreBookForSaving() -> LoreBookModel {
        var loreBook = loreBook

        loreBook.name = loreBook.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if loreBook.name.isEmpty {
            loreBook.name = "Untitled Lorebook"
        }

        loreBook.description = loreBook.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if loreBook.description?.isEmpty == true {
            loreBook.description = nil
        }

        loreBook.tokenBudget = Int(tokenBudgetText.trimmingCharacters(in: .whitespacesAndNewlines))
        loreBook.entries = loreBook.entries.enumerated().map { index, entry in
            var entry = entry
            entry.order = entry.order ?? index
            return entry
        }

        return loreBook
    }
}
