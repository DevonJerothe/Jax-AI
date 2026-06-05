import SwiftLLMSDK
import Foundation

@MainActor
@Observable
final class CharImportViewModel {

    private let charImporter: CharImporter

    var urlEntry: String = ""
    var characterCard: CharacterCardModel?
    var importError: String?
    var isImporting = false

    init() {
        self.charImporter = CharImporter(urlSession: URLSession.shared)
    }

    var canImportRemoteCard: Bool {
        urlEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isImporting == false
    }

    func importRemoteCard() async {
        let trimmedURL = urlEntry.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL), url.scheme?.isEmpty == false else {
            importError = "Enter a valid remote URL."
            return
        }

        await importCard(from: url)
    }

    func importLocalCard(from url: URL) async {
        await importCard(from: url)
    }

    private func importCard(from url: URL) async {
        isImporting = true
        importError = nil

        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            isImporting = false
        }

        do {
            let card = try await charImporter.importCard(from: url)
            characterCard = CharacterCardModel(fromChub: card)
        } catch {
            importError = userFacingImportError(for: error)
        }
    }

    private func userFacingImportError(for error: Error) -> String {
        let description = error.localizedDescription

        if description == "The data couldn’t be read because it isn’t in the correct format." {
            return "The selected file does not contain a supported character card."
        }

        return description
    }
}
