//
//  CharacterStore.swift
//  PocketAI
//
//  Created by devon jerothe on 4/23/26.
//

import Foundation

@MainActor
@Observable
final class CharacterStore {
    private let characterRepository: CharacterRepository
    
    private var observerQueue: [CheckedContinuation<Void, Never>] = []
    
    private(set) var characters: [CharacterCardModel] = []
    
    init(
        characterRepository: CharacterRepository
    ) {
        self.characterRepository = characterRepository
    }
    
    private func waitForObserver() async {
        await withCheckedContinuation { continuation in
            observerQueue.append(continuation)
        }
    }
    
    func startObserving() async {
        do {
            for try await updatedCharacters in try characterRepository.observeAll() {
                self.characters = updatedCharacters
                
                let queue = observerQueue
                observerQueue.removeAll()
                queue.forEach { $0.resume() }
            }
        } catch {
            print("Error observing character records: \(error)")
        }
    }
    
    func character(withID characterID: UUID) -> CharacterCardModel? {
        characters.first(where: { $0.id == characterID })
    }

    func deleteCharacterCard(_ characterCard: CharacterCardModel) async throws {
        try characterRepository.delete(characterCard)
        await waitForObserver()
    }

    func saveCharacterCard(_ characterCard: CharacterCardModel) async throws {
        try characterRepository.save(characterCard)
        await waitForObserver()
    }

    func updatePrivacy(for characterID: UUID, isPrivate: Bool) async throws {
        guard let index = characters.firstIndex(where: { $0.id == characterID }) else {
            throw AppDBError.recordNotFound("character: \(characterID.uuidString)")
        }

        characters[index].isPrivate = isPrivate
        try characterRepository.save(characters[index])
        await waitForObserver()
    }
}
