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
            switch navManager.currentRoot {
            case .chatListView:
                ChatListView()
                    .tint(.white)
            }
        }
        .environment(navManager)
        .environment(serviceContainer)
    }
}
