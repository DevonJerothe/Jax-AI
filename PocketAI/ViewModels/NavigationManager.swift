//
//  NavigationManager.swift
//  PocketAI
//
//  Created by devon jerothe on 3/12/25.
//

import SwiftUI

@Observable
class NavigationManager {
    enum RootRoute {
        case chatListView
//        case chatView(ChatModel)
//        case settingsView
    }

    var currentRoot: RootRoute = .chatListView


    func navigateToHome() {
        self.currentRoot = .chatListView
    }

//    func navigateToChat(_ chat: ChatModel) {
//        self.currentRoot = .chatView(chat)
//    }
}
