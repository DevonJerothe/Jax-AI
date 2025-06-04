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
        case settingsView
        case newChatView
    }

    enum SheetType: Identifiable {
        case newChat
        case connectionSettings
        case characterDetails(CharacterCardModel)
        case chatDetails(ChatModel)

        var id: String {
            switch self {
            case .newChat:
                return "newChat"
            case .connectionSettings:
                return "connectionSettings"
            case .characterDetails(let character):
                return "characterDetails_\(character.id)"
            case .chatDetails(let chat):
                return "chatDetails_\(chat.id)"
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

    // MARK: - Navigation Methods
    func navigateHome() {
        currentTab = .chatList
        chatListPath = NavigationPath()
        characterListPath = NavigationPath()
        settingsPath = NavigationPath()
    }

    // Navigates to specific chat, optionally preserving the current path
    // - Parameter chat: The chat to navigate to
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToChat(chat: ChatModel, keepCurrentPath: Bool = false) {
        if keepCurrentPath {
            appendToCurrentPath(Destination.chatView(chat))
        } else {
            currentTab = .chatList
            clearPath(for: .chatList)
            chatListPath.append(Destination.chatView(chat))
        }
    }

    // Navigates to specific character, optionally preserving the current path
    // - Parameter character: The character to navigate to
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToCharacter(character: CharacterCardModel, keepCurrentPath: Bool = false) {
        if keepCurrentPath {
            appendToCurrentPath(Destination.characterView(character))
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.characterView(character))
        }
    }

    // Navigates to settings, optionally preserving the current path
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToSettings(keepCurrentPath: Bool = false) {
        if keepCurrentPath {
            appendToCurrentPath(Destination.settingsView)
        } else {
            currentTab = .settings
            clearPath(for: .settings)
        }
    }

    // Navigates to new chat, optionally preserving the current path
    func navigateToNewChat() {
        chatListPath = NavigationPath()
        chatListPath.append(Destination.newChatView)
        currentTab = .chatList
    }

    /// Navigates to a specified destination within the current tab's navigation stack
    /// - Parameter destination: The destination to navigate to
    func goTo(destination: Destination) {
        appendToCurrentPath(destination)
    }
}
