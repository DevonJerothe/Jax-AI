import Foundation 
import SwiftUI 
import GRDB 

@Observable
class CharacterCardsViewModel {
    private let characterRepository: CharacterRepository
    private let serviceContainer = ServiceContainer.shared

    var characterCards: [CharacterCardModel] = []

    init(
        characterRepository: CharacterRepository = ServiceContainer.shared.getCharacterRepository(),
        characterCards: [CharacterCardModel] = []
    ) {
        self.characterRepository = characterRepository
        self.characterCards = characterCards
    }

    func loadCharacterCards() {
        do {
            print("CharacterCardsViewModel: Loading character cards from database...")
            self.characterCards = try characterRepository.getAll()
            print("CharacterCardsViewModel: Loaded \(self.characterCards.count) character cards")
        } catch {
            print("CharacterCardsViewModel: Failed to load character cards: \(error)")
        }
    }

    func deleteCharacterCard(card: CharacterCardModel) {
        do {
            try characterRepository.delete(card)
            self.loadCharacterCards()
        } catch {
            print("CharacterCardsViewModel: Failed to delete character card: \(error)")
        }
    }
}