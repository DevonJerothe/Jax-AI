//
//  ChatListView.swift
//  PocketAI
//
//  Created by devon jerothe on 6/2/25.
//

import SwiftUI

struct ChatListView: View {
    @Environment(NavigationManager.self) var navManager
    @State var viewModel: ChatListViewModel = .init()

    private var connectionManager = ServiceContainer.shared

    var body: some View {
        NavigationView {
            VStack {
                if connectionManager.isConnected == false {
                    // API Banner
                    APIStatusBanner()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                List {
                    // Character Cards as a Section Header
                    Section(
                        header: Text("Characters").font(.title2).fontWeight(.bold)
                    ) {
                        CharacterCardsListView(viewModel: viewModel)
                            .listRowInsets(EdgeInsets())
                    }
                    .listSectionSeparator(.hidden)

                    // Recent Chats
                    Section(
                        header: Text("Recent Chats").font(.title2).fontWeight(.bold)
                    ) {
                        ForEach(viewModel.chats, id: \.id) { chat in
                            RecentChatRow(chat: chat)
                                .listRowInsets(EdgeInsets())
                        }
                        .onDelete(perform: viewModel.deleteChat)
                    }
                    .listSectionSeparator(.hidden)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Jax AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navManager.navigateToNewChat()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                print("ChatListView onAppear called")
                if viewModel.chats.isEmpty {
                    viewModel.refreshData()
                }
                print(
                    "loaded \(viewModel.characterCards.count) character cards")
                print("loaded \(viewModel.chats.count) chats")
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .chatDataChanged)
            ) { notification in
                // Refresh data when any chat changes
                print(
                    "Chat data changed notification received, refreshing chat list..."
                )
                viewModel.refreshData()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .chatStreamingChanged)
            ) { notification in
                print("Chat streaming changed notification received, refreshing chat list item...") 
                if let chat = notification.object as? ChatModel {
                    print("Chat status changed: \(chat.isLoading), \(chat.isStreaming), \(chat.isThinking)")
                    viewModel.updateChatInList(chat)
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
                            if let newChat = viewModel.createNewChat(
                                fromCharacter: character)
                            {
                                navManager.navigateToChat(chat: newChat)
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
    let character: CharacterCardModel

    var body: some View {
        VStack(spacing: 8) {
            AvatarImage(image: character.getAvatarImg(), size: 80)

            // Character Name
            Text(character.name ?? "Unknown")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

// MARK: - Add Character Button
struct AddCharacterButton: View {
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                        .font(.title2)
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.5),
                            style: StrokeStyle(lineWidth: 2, dash: [5]))
                )

            Text("Add")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
        }
        .onTapGesture {
            // Navigate to add character
            navManager.navigateToNewChat()
        }
    }
}

// MARK: - Recent Chat Row
struct RecentChatRow: View {
    @Environment(NavigationManager.self) var navManager
    let chat: ChatModel

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(image: chat.getAvatarImg(), size: 48)

            VStack(alignment: .leading, spacing: 4) {
                // Character Name
                Text(chat.chatTitle)
                    .fontWeight(.medium)

                if chat.isLoading || chat.isStreaming {
                    LoadingIndicator(color: .secondary, size: 15)
                } else {
                    if let lastMessage = chat.messages.last {
                        Text(lastMessage.getRolePlayText(cardName: chat.chatTitle))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

            }

            Spacer()

            // Timestamp
            Text(getFormattedTimestamp())
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to this chat
            navManager.navigateToChat(chat: chat)
        }
    }

    private func getLastMessagePreview() -> String {
        // Get the last message from the chat
        guard let lastMessage = chat.messages.last else {
            return "No messages yet"
        }
        return lastMessage.text.isEmpty ? "..." : lastMessage.text
    }

    private func getFormattedTimestamp() -> String {
        // Format the timestamp of the last message
        guard let lastMessage = chat.messages.last else {
            return ""
        }

        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(lastMessage.createdAt) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: lastMessage.createdAt)
        } else if calendar.isDateInYesterday(lastMessage.createdAt) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEE"
            return formatter.string(from: lastMessage.createdAt)
        }
    }
}
