import Foundation

@MainActor
@Observable
final class LoreBookStore {
    private let loreBookRepository: LoreBookRepository

    private var observerQueue: [CheckedContinuation<Void, Never>] = []

    private(set) var loreBooks: [LoreBookModel] = []

    init(loreBookRepository: LoreBookRepository) {
        self.loreBookRepository = loreBookRepository
    }

    private func waitForObserver() async {
        await withCheckedContinuation { continuation in
            observerQueue.append(continuation)
        }
    }

    func startObserving() async {
        do {
            for try await updatedLoreBooks in try loreBookRepository.observeAll() {
                self.loreBooks = updatedLoreBooks

                let queue = observerQueue
                observerQueue.removeAll()
                queue.forEach { $0.resume() }
            }
        } catch {
            print("Error observing lore book records: \(error)")
        }
    }

    func loreBook(withID loreBookID: UUID) -> LoreBookModel? {
        loreBooks.first(where: { $0.id == loreBookID })
    }

    func deleteLoreBook(_ loreBook: LoreBookModel) async throws {
        try loreBookRepository.delete(loreBook)
        await waitForObserver()
    }

    func saveLoreBook(_ loreBook: LoreBookModel) async throws {
        try loreBookRepository.save(loreBook)
        await waitForObserver()
    }

    func updatePrivacy(for loreBookID: UUID, isPrivate: Bool) async throws {
        guard let index = loreBooks.firstIndex(where: { $0.id == loreBookID }) else {
            throw AppDBError.recordNotFound("lore book: \(loreBookID.uuidString)")
        }

        loreBooks[index].isPrivate = isPrivate
        try loreBookRepository.save(loreBooks[index])
        await waitForObserver()
    }
}
