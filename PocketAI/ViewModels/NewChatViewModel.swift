//
//  CharacterImportView.swift
//  PocketAI
//
//  Created by devon jerothe on 4/4/25.
//

import SwiftUI

@MainActor
@Observable
final class NewChatViewModel {
    private let characterStore: CharacterStore
    private let chatStore: ChatStore
    
    var chatName: String = ""
    var systemPrompt: String = ""
    var initialMessage: String = ""
    var imgData: Data?

    var characterCard: CharacterCardModel?

    init(characterStore: CharacterStore? = nil, chatStore: ChatStore? = nil) {
        self.characterStore = characterStore ?? ServiceContainer.shared.getCharacterStore()
        self.chatStore = chatStore ?? ServiceContainer.shared.getChatStore()
    }

    func getAvatarImg() -> Image? {
        if let imgData = imgData, let uiImage = UIImage(data: imgData) {
            return Image(uiImage: uiImage)
        }
        return nil
    }

    func isCreateDisabled(type: NewChatTab) -> Bool {
        switch type {
        case .manual:
            return self.chatName.isEmpty && self.systemPrompt.isEmpty
        case .importCard:
            return self.characterCard == nil
        case .charHub: 
            return true 
        }
    }

    func createCharacterCard(type: NewChatTab) async -> CharacterCardModel? {
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
            fatalError("Failed to create character card")
        }

        do {
            try await self.characterStore.saveCharacterCard(characterCard)
        } catch {
            print("Failed to save character card: \(error)")
            return nil
        }
        
        return characterCard
    }
    
    func createChat(type: NewChatTab) async -> ChatModel? {
        let _ = await createCharacterCard(type: type)

        guard let characterCard else {
            fatalError("Failed to add new chat")
        }

        let newChat = ChatModel(fromCard: characterCard)
        do {
            try await self.chatStore.addChat(newChat)
            
            return newChat
        } catch {
            print("Failed to save chat: \(error)")
            return nil
        }
    }
}
