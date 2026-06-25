//
//  ChatListView.swift
//  PocketAI
//
//  Created by devon jerothe on 6/2/25.
//

import SwiftUI

struct ChatListView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(ServiceContainer.self) var serviceContainer
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: ChatListViewModel = .init()

    var body: some View {
        VStack {
            List {
                Section(
                    header: Text("Characters").font(.title2).fontWeight(.bold)
                ) {
                    CharacterCardsListView(viewModel: viewModel)
                        .padding(.top, 12)
                        .listRowInsets(EdgeInsets())
                }
                .background(appTheme.backgroundColor.color)
                .listSectionSeparator(.hidden)

                Section(
                    header: Text("Recent Chats").font(.title2).fontWeight(.bold)
                ) {
                    ForEach(viewModel.chats, id: \.id) { chat in
                        RecentChatRow(chat: chat)
                            .listRowInsets(EdgeInsets())
                    }
                    .onDelete { indexSet in
                        Task {
                            await viewModel.deleteChat(at: indexSet)
                        }
                    }
                }
                .background(appTheme.backgroundColor.color)
                .listSectionSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(appTheme.backgroundColor.color)
        .safeAreaInset(edge: .top, spacing: 0) {
            if serviceContainer.isConnected == false {
                APIStatusBanner()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Jax AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Quick Chat") {
                        Task {
                            if let chat = await viewModel.quickChat() {
                                navManager.navigateToChat(chatID: chat.id)
                            }
                        }
                    }
                    Button("Character Chat") {
                        navManager.navigateToCharacterCards(keepCurrentPath: true, startChat: true)
                    }
                    
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - CharacterCardsListView
struct CharacterCardsListView: View {
    @Environment(NavigationManager.self) var navManager
    let viewModel: ChatListViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(viewModel.characterCards, id: \.id) { character in
                    CharacterCardView(character: character)
                        .onTapGesture {
                            Task {
                                if let newChat = await viewModel.createNewChat(fromCharacter: character) {
                                    navManager.navigateToChat(chatID: newChat.id)
                                }
                            }
                        }
                }

                // Add Character Button
                AddCharacterButton()
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Character Card View
struct CharacterCardView: View {
    @Environment(\.appTheme) private var appTheme

    let character: CharacterCardModel

    var body: some View {
        VStack(spacing: 8) {
            AvatarImage(image: character.getAvatarImg(), size: 80)

            // Character Name
            Text(character.name ?? "Unknown")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(appTheme.primaryText.color)
                .frame(maxWidth: 150)
                .lineLimit(1)
        }
    }
}

// MARK: - Add Character Button
struct AddCharacterButton: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(appTheme.secondaryAction.color)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "plus")
                        .foregroundColor(appTheme.secondaryText.color)
                        .font(.title2)
                )
                .overlay(
                    Circle()
                        .stroke(
                            appTheme.borderColor.color,
                            style: StrokeStyle(lineWidth: 2, dash: [5]))
                )

            Text("Add")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(appTheme.secondaryText.color)
        }
        .onTapGesture {
            // Navigate to add character
            navManager.navigateToCharacterCards()
        }
    }
}

// MARK: - Recent Chat Row
struct RecentChatRow: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme

    let userPersonaName = ServiceContainer.shared.getPersonaName
    let chat: ChatModel

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(image: chat.getAvatarImg(), size: 48)

            VStack(alignment: .leading, spacing: 4) {
                // Character Name
                Text(chat.chatTitle)
                    .fontWeight(.medium)
                    .foregroundColor(appTheme.primaryText.color)

                if chat.status != .idle {
                    LoadingIndicator(color: appTheme.secondaryText.color, size: 15)
                } else {
                    if let lastMessage = chat.messages.last {
                        Text(lastMessage.getRolePlayText(cardName: chat.chatTitle, personaName: userPersonaName))
                            .font(.subheadline)
                            .foregroundColor(appTheme.secondaryText.color)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Timestamp
            Text(formattedTimestamp)
                .font(.caption)
                .foregroundColor(appTheme.secondaryText.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            navManager.navigateToChat(chatID: chat.id)
        }
    }

    private var formattedTimestamp: String {
        guard let lastMessage = chat.messages.last else {
            return ""
        }

        return AppDateFormatting.chatListTimestamp(from: lastMessage.createdAt)
    }
}
