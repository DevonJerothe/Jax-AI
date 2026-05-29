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
        case chatView(UUID)
        case characterView(UUID)
        case characterCardsView
        case chatSettings(UUID)
        case chatNotes(UUID)
        case settingsView
        case connectionSettings
        case newChatView(Bool)
        case booruBrowserView
        case chubAIBrowserView
        case chubImportView
    }

    enum SheetType: Identifiable {
        case newChat
        case connectionSettings
        case characterDetails(UUID)
        case chatSettings(UUID)
        case newTemplateView(String?)
        case chatNote(UUID, UUID?)
        case booruBrowserView
        case chubAIBrowserView

        var id: String {
            switch self {
            case .newChat:
                return "newChat"
            case .connectionSettings:
                return "connectionSettings"
            case .characterDetails(let characterID):
                return "characterDetails_\(characterID.uuidString)"
            case .chatSettings(let chatID):
                return "chatDetails_\(chatID.uuidString)"
            case .newTemplateView(let templateKey):
                return "newTemplateView_\(templateKey ?? "new")"
            case .chatNote(let chatID, let noteID):
                return "chatNote_\(chatID.uuidString)_\(noteID?.uuidString ?? "new")"
            case .booruBrowserView:
                return "booruBrowserView"
            case .chubAIBrowserView:
                return "chubAIBrowserView"
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
    func navigateToChat(chatID: UUID, keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.chatView(chatID))
        } else {
            currentTab = .chatList
            clearPath(for: .chatList)
            chatListPath.append(Destination.chatView(chatID))
        }
    }

    func navigateToChatSettings(chatID: UUID, sheet: Bool = false) {
        if sheet {
            presentedSheet = .chatSettings(chatID)
        } else {
            presentedSheet = nil
            appendToCurrentPath(Destination.chatSettings(chatID))
        }
    }

    func navigateToChatNotes(chatID: UUID) {
        presentedSheet = nil
        appendToCurrentPath(Destination.chatNotes(chatID))
    }

    // Navigates to specific character, optionally preserving the current path
    // - Parameter character: The character to navigate to
    // - Parameter keepCurrentPath: Whether to preserve the current path (default is false)
    func navigateToCharacter(characterID: UUID, keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.characterView(characterID))
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.characterView(characterID))
        }
    }

    func navigateToCharacterCards(keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.characterCardsView)
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
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

    func navigateToConnectionSettings(keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.connectionSettings)
        } else {
            currentTab = .settings
            clearPath(for: .settings)
            settingsPath.append(Destination.connectionSettings)
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

    func navigateToHubArchive(keepCurrentPath: Bool = false) {
        presentedSheet = nil
        if keepCurrentPath {
            appendToCurrentPath(Destination.booruBrowserView)
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.booruBrowserView)
        }
    }

    func navigateToChubAIBrowser(keepCurrentPath: Bool = false) {
        if keepCurrentPath {
            appendToCurrentPath(Destination.chubAIBrowserView)
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.chubAIBrowserView)
        }
    }

    func navigateToChubImport(keepCurrentPath: Bool = false) {
        if keepCurrentPath {
            appendToCurrentPath(Destination.chubImportView)
        } else {
            currentTab = .characterList
            clearPath(for: .characterList)
            characterListPath.append(Destination.chubImportView)
        }
    }

    func showNewTemplateView(templateKey: String? = nil) {
        presentedSheet = .newTemplateView(templateKey)
    }

    func showChatNoteView(chatID: UUID, noteID: UUID? = nil) {
        presentedSheet = .chatNote(chatID, noteID)
    }

    /// Navigates to a specified destination within the current tab's navigation stack
    /// - Parameter destination: The destination to navigate to
    func goTo(destination: Destination) {
        presentedSheet = nil
        appendToCurrentPath(destination)
    }
}
