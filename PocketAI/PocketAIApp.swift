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
                    Text("TODO: Character List")
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
                    Text("TODO: Settings")
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
        }
        .environment(navManager)
        .environment(serviceContainer)

    }

    @ViewBuilder
    private func destinationView(for destination: NavigationManager.Destination) -> some View {
        switch destination {
        case .chatView(let chat):
            ChatView(chatModel: chat)
                .toolbar(.hidden, for: .tabBar)
        case .characterView(let character):
            Text("Character View")
        case .settingsView:
            Text("Settings View")
        case .newChatView:
            Text("New Chat View")
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: NavigationManager.SheetType) -> some View {
        Text("TODO: Sheet View")
    }
}
