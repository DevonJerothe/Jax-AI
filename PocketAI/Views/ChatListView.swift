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
                ScrollView {
                    VStack {
                        // Character Cards Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Characters")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Character Cards ScrollView
                            CharacterCardsListView(viewModel: viewModel)
                        }
                        .padding(.vertical, 24)

                        // Recent Chats Section 
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Chats")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            // Recent Chats List
                            RecentChatsList(chats: viewModel.chats)
                        }
                    }
                }
            }
            .navigationTitle("Jax AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navManager.navigateToNewChat(sheet: true)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear() {
                print("ChatListView onAppear called")
                viewModel.refreshData()
                print("loaded \(viewModel.characterCards.count) character cards")
                print("loaded \(viewModel.chats.count) chats")
            }
            .onReceive(NotificationCenter.default.publisher(for: .chatDataChanged)) { notification in
                // Refresh data when any chat changes
                print("Chat data changed notification received, refreshing chat list...")
                viewModel.refreshData()
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
                            if let newChat = viewModel.createNewChat(fromCharacter: character) {
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
            // Character Avatar
            ZStack {
                if let imageData = character.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.title2)
                        )
                }
            }
            
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
                        .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            
            Text("Add")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
        }
        .onTapGesture {
            // Navigate to add character
        }
    }
}

// MARK: - Recent Chats List
struct RecentChatsList: View {
    let chats: [ChatModel]
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(chats, id: \.id) { chat in
                RecentChatRow(chat: chat)
                
                if chat != chats.last {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.leading, 72)
                }
            }
        }
    }
}

// MARK: - Recent Chat Row
struct RecentChatRow: View {
    @Environment(NavigationManager.self) var navManager
    let chat: ChatModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Character Avatar
            ZStack {
                chat.getAvatarImg()
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .foregroundColor(.gray)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Character Name
                Text(chat.chatTitle)
                    .fontWeight(.medium)

                // TODO: Last Message Preview
                Text(chat.messages.last?.getRolePlayText(cardName: chat.chatTitle) ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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
