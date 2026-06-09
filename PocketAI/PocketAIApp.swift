//
//  PocketAIApp.swift
//  PocketAI
//
//  Created by devon jerothe on 3/11/25.
//

import SwiftUI
import GRDB

@main
struct PocketAIApp: App {

    @State var navManager: NavigationManager = .init()
    @State var serviceContainer: ServiceContainer = .shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        print("PocketAIApp initializing...")
        // Initialize database
        let _ = DBManager.shared
        print("Database initialized successfully")
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $navManager.currentTab) {
                // Chat List Tab
                NavigationStack(path: $navManager.chatListPath) {
                    ChatListView()
                        .navigationDestination(for: NavigationManager.Destination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tabItem {
                    Image(systemName: "message")
                    Text("Chats")
                }
                .tag(NavigationManager.Tab.chatList)

                // Character List Tab
                NavigationStack(path: $navManager.characterListPath) {
                    CharacterCardsView()
                        .navigationDestination(for: NavigationManager.Destination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tabItem {
                    Image(systemName: "person")
                    Text("Characters")
                }
                .tag(NavigationManager.Tab.characterList)

                // Settings Tab
                NavigationStack(path: $navManager.settingsPath) {
                    GeneralSettingsView()
                        .navigationDestination(for: NavigationManager.Destination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
                .tag(NavigationManager.Tab.settings)
            }
            .sheet(item: $navManager.presentedSheet) { sheet in
                sheetView(for: sheet)
                    .presentationBackground(serviceContainer.currentTheme.backgroundColor.color)
            }
            .tint(serviceContainer.currentTheme.tintColor.color)
            .environment(\.appTheme, serviceContainer.currentTheme)
            .task {
                serviceContainer.bootstrap()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else {
                    return
                }

                // Fire after any view onAppear / onDisappear
                DispatchQueue.main.async {
                    serviceContainer.lockForAppResumeIfNeeded()
                }
            }
        }
        .environment(navManager)
        .environment(serviceContainer)
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationManager.Destination) -> some View {
        switch destination {
        case .chatView(let chatID):
            ChatView(chatID: chatID)
                .toolbar(.hidden, for: .tabBar)
        case .characterView(let characterID):
            CharacterCardSettingsView(characterID: characterID)
        case .characterCardsView:
            CharacterCardsView()
        case .loreBookListView(let chatID):
            LoreBookListView(chatID: chatID)
        case .loreBookView(let loreBookID):
            LoreBookView(loreBookID: loreBookID)
        case .settingsView:
            GeneralSettingsView()
        case .connectionSettings:
            ConnectionSettingsView()
        case .newChatView(let createChar):
            if createChar {
                CharacterCardSettingsView(isNew: true)
            } else {
                NewChatView()
            }
        case .chatSettings(let chatID):
            ChatSettingsView(chatID: chatID)
        case .chatNotes(let chatID):
            ChatNotesView(chatID: chatID)

        #if !APPSTORE
        case .booruBrowserView:
            BooruBrowserView()
        case .chubAIBrowserView:
            ChubAIBrowserView()
        #endif
        
        case .charImportView(let importType):
            CharImportView(importType: importType)
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: NavigationManager.SheetType) -> some View {
        switch sheet {
        case .newTemplateView(let templateKey):
            NewTemplateView(templateKey: templateKey)
        case .chatNote(let chatID, let noteID):
            ChatNoteView(chatID: chatID, noteID: noteID)
        default:
            Text("Not Implemented")
        }
    }
}
