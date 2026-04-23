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
    
    func deleteCharacterCard(_ characterCard: CharacterCardModel) throws {
        try characterRepository.delete(characterCard)
    }

    func addCharacterCard(_ characterCard: CharacterCardModel) throws {
        try characterRepository.save(characterCard)
    }

    func updatePrivacy(for characterID: UUID, isPrivate: Bool) throws {
        guard let index = characters.firstIndex(where: { $0.id == characterID }) else {
            throw AppDBError.recordNotFound("character: \(characterID.uuidString)")
        }

        characters[index].isPrivate = isPrivate
        try characterRepository.save(characters[index])
    }
}
