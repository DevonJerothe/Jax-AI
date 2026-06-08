import Foundation
import SwiftLLMSDK

public enum CharImportType: Hashable {
    case characterCard
    case loreBook
}

@MainActor
@Observable
final class CharImportViewModel {

    private let charImporter: CharImporter
    let importType: CharImportType

    var urlEntry: String = ""
    var characterCard: CharacterCardModel?
    var loreBook: LoreBookModel?
    var importError: String?
    var isImporting = false

    init(importType: CharImportType = .characterCard) {
        self.importType = importType
        self.charImporter = CharImporter(urlSession: URLSession.shared)
    }

    var canImportRemoteContent: Bool {
        urlEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && isImporting == false
    }

    func importRemoteContent() async {
        let trimmedURL = urlEntry.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL), url.scheme?.isEmpty == false else {
            importError = "Enter a valid remote URL."
            return
        }

        await importContent(from: url)
    }

    func importLocalContent(from url: URL) async {
        await importContent(from: url)
    }

    private func importContent(from url: URL) async {
        isImporting = true
        importError = nil
        characterCard = nil
        loreBook = nil

        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            isImporting = false
        }

        do {
            switch importType {
            case .characterCard:
                let card = try await charImporter.importCard(from: url)
                characterCard = CharacterCardModel(fromChub: card)
            case .loreBook:
                let importedLoreBook = try await charImporter.importLoreBook(from: url)
                loreBook = LoreBookModel(fromImport: importedLoreBook)
            }
        } catch {
            importError = userFacingImportError(for: error)
        }
    }

    private func userFacingImportError(for error: Error) -> String {
        let description = error.localizedDescription

        if description == "The data couldn’t be read because it isn’t in the correct format." {
            switch importType {
            case .characterCard:
                return "The selected file does not contain a supported character card."
            case .loreBook:
                return "The selected file does not contain a supported lorebook JSON file."
            }
        }

        return description
    }
}