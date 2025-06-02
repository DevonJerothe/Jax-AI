//
//  CharacterImportView.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//

import SwiftLLMSDK
import SwiftUI

@Observable
class NewChatViewModel {
    private let characterRepository: CharacterRepository
    private let serviceContainer: ServiceContainer = .shared
    private let characterImporter: CharacterImporterService
    
    var urlEntry: String = ""
    var chatName: String = ""
    var systemPrompt: String = ""
    var initialMessage: String = ""
    var imgData: Data?

    var importError: String?

    var characterCard: CharacterCardModel?

    init(
        characterRepository: CharacterRepository = ServiceContainer.shared
            .getCharacterRepository()
    ) {
        self.characterRepository = characterRepository

        // For now only support chub AI cards.. tbh not even sure other sources
        self.characterImporter = ChubImporter(urlSession: URLSession.shared)
    }

    func isCreateDisabled(type: NewChatTab) -> Bool {
        switch type {
        case .manual:
            return self.chatName.isEmpty && self.systemPrompt.isEmpty
        case .importCard:
            return self.characterCard == nil
        }
    }

    func importCharacterCard(stringURL: String) async {
        guard let cardURL = URL(string: stringURL) else {
            print("Failed to load URL")
            return
        }

        do {
            let llmCard = try await characterImporter.getCardViaURL(cardURL)
            switch llmCard {
            case .success(let card):
                // Convert LLM Card type to our DB Model
                let characterCard = CharacterCardModel.init(fromChub: card)
                await MainActor.run {
                    // LLM model is non sendable so we get dumb swift warnings if in MainActor
                    self.characterCard = characterCard
                }
            case .failure(let error):
                if case APIError.unsupportedURLImport = error {
                    self.importError = "Unsupported Character Card URL"
                } else {
                    self.importError = error.localizedDescription
                }
                print("Import ERROR: \(error.localizedDescription)")
            }
        } catch (let error) {
            print("Import ERROR: \(error.localizedDescription)")
        }
    }
    
    func createChat(type: NewChatTab) -> ChatModel {
        if type == .manual {
            self.characterCard = CharacterCardModel(
                name: self.chatName,
                description: self.systemPrompt,
                firstMessage: self.initialMessage,
                systemPrompt: self.systemPrompt,
                imageData: self.imgData
            )
        }

        guard let characterCard else {
            fatalError("Failed to add new chat")
        }

        let newChat = ChatModel(fromCard: characterCard)
        return newChat
    }

    func saveCharacterCard() {
        if let characterCard {
            try! self.characterRepository.save(characterCard)
        }
    }
}
