//
//  NavigationManager.swift
//  PocketAI
//
//  Created by devon jerothe on 3/12/25.
//

import SwiftUI

@Observable
class NavigationManager {
    enum Tab {
        case chatList
        case characterList
        case settings
    }

    enum Destination: Hashable {
        case chatView(ChatModel)
        case characterView(CharacterCardModel)
        case characterCardsView
        case chatSettings(ChatViewModel)
        case settingsView
        case newChatView(Bool)
    }

    enum SheetType: Identifiable {
        case newChat
        case connectionSettings
        case characterDetails(CharacterCardModel)
        case chatSettings(ChatViewModel)

        var id: String {
            switch self {
            case .newChat:
                return "newChat"
            case .connectionSettings:
                return "connectionSettings"
            case .characterDetails(let character):
                return "characterDetails_\(character.id)"
            case .chatSettings(let chat):
                return "chatDetails_\(chat.model.id)"
            }
        }
    }

    var currentTab: Tab = .chatList

    // MARK: - Navigation Paths
    var chatListPath = NavigationPath()
    var characterListPath = NavigationPath()
    var settingsPath = NavigationPath()
    var presentedSheet: SheetType? = nil
    
    private func getCurrentPath() -> NavigationPath {
        switch currentTab {
        case .chatList:
            return self.chatListPath
        case .characterList:
            return self.characterListPath
        case .settings:
            return self.settingsPath
        }
    }
    
    // Helper method to modify the correct navigation path based on current tab
    private func appendToCurrentPath(_ destination: Destination) {
        switch currentTab {
        case .chatList:
            chatListPath.append(destination)
        case .characterList:
            characterListPath.append(destination)
        case .settings:
            settingsPath.append(destination)
        }
    }
    
    // Helper method to clear the correct navigation path based on tab
    private func clearPath(for tab: Tab) {
        switch tab {
        case .chatList:
            chatListPath = NavigationPath()
        case .characterList:
            characterListPath = NavigationPath()
        case .settings:
            settingsPath = NavigationPath()
        }
    }

    // Pop the last item from the current path
    func popBack() {
        presentedSheet = nil
        switch currentTab {
        case .chatList:
            if !chatListPath.isEmpty {
                chatListPath.removeLast()
            }
        case .characterList:
            if !characterListPath.isEmpty {
                characterListPath.removeLast()
            }
        case .settings:
            if !settingsPath.isEmpty {
                settingsPath.removeLast()
            }
        }
    }

    // MARK: - Navigation Methods
    func navigateHome() {
        presentedSheet = nil
        currentTab = .chatList
        chatListPath = NavigationPath()
        characterListPath = NavigationPath()
        settingsPath = NavigationPath()
    }

    // Navigates to specific chat, optionally preserving the current path
    // - Parameter chat: The chat to navigate to
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToChat(chat: ChatModel, keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.chatView(chat))
        } else {
            currentTab = .chatList
            clearPath(for: .chatList)
            chatListPath.append(Destination.chatView(chat))
        }
    }

    func navigateToChatSettings(chat: ChatViewModel, sheet: Bool = false) {
        if sheet {
            presentedSheet = .chatSettings(chat)
        } else {
            presentedSheet = nil
            appendToCurrentPath(Destination.chatSettings(chat))
        }
    }

    // Navigates to specific character, optionally preserving the current path
    // - Parameter character: The character to navigate to
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToCharacter(character: CharacterCardModel, keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.characterView(character))
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.characterView(character))
        }
    }

    func navigateToCharacterCards(keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.characterCardsView)
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.characterCardsView)
        }
    }

    // Navigates to settings, optionally preserving the current path
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToSettings(keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.settingsView)
        } else {
            currentTab = .settings
            clearPath(for: .settings)
        }
    }

    // Navigates to new chat, optionally preserving the current path
    func navigateToNewChat(keepCurrentPath: Bool = false, sheet: Bool = false, createCharacterCard: Bool = false) {
        if sheet {
            presentedSheet = .newChat
            return 
        } 
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.newChatView(createCharacterCard))
        } else {
            currentTab = .chatList
            clearPath(for: .chatList)
            chatListPath.append(Destination.newChatView(createCharacterCard))
        }
    }

    /// Navigates to a specified destination within the current tab's navigation stack
    /// - Parameter destination: The destination to navigate to
    func goTo(destination: Destination) {
        presentedSheet = nil
        appendToCurrentPath(destination)
    }
}
