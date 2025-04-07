//
//  ChatListView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

struct ChatListView: View {

    @Environment(NavigationManager.self) var navManager
    @State var viewModel: ChatListViewModel = .init()
    
    private var connectionManager = ServiceContainer.shared

    var body: some View {
        NavigationStack {
            VStack {
                // List with swipe actions
                List {
                    ForEach(viewModel.chats, id: \.id) { chat in
                        ZStack {
                            // Background and border as a single unit
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemFill))
                                .cornerRadius(10)
                            
                            // Content
                            HStack(spacing: 12) {
                                // Avatar/Profile Image
                                chat.getAvatarImg()
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 45, height: 45)
                                    .foregroundColor(.gray)
                                    .clipShape(Circle())
                                
                                // Chat info
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(chat.chatTitle)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        // Time indicator (placeholder - could show creation date)
                                        Text("Today")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text(chat.messages.last?.text ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(
                            // Hide chevron set by navigation link
                            NavigationLink(
                                "",
                                destination: ChatView(chatModel: chat)
                            )
                            .opacity(0)
                        )
                        .padding(.vertical, 3) // Add a small gap between list items
                        // .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        Task {
                            viewModel.deleteChat(at: indexSet)
                        }
                    }
                }
                .environment(\.defaultMinListRowHeight, 10) // Reduce minimum row height
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolBarHeader(
                    leadingButtonIcon: connectionManager.isConnected ? "network" : "network.slash",
                    leadingIconColor: connectionManager.isConnected ? .accentColor : .red,
                    trailingButtonIcon: "plus",
                    leadingButtonAction: {
                        viewModel.showConnectionSheet.toggle()
                    }, 
                    trailingButtonAction: {
                        viewModel.showNewChatSheet.toggle()
                    }
                )
            }
            .navigationTitle("Pocket AI")
            .navigationBarTitleDisplayMode(.inline)
            .padding()
            .sheet(isPresented: $viewModel.showNewChatSheet) {
                NewChatSheetView(onSave: { newChat in
                    viewModel.showNewChatSheet = false
                    viewModel.createNewChat(chatModel: newChat)
                })
            }
            .sheet(isPresented: $viewModel.showConnectionSheet) {
                ConnectionSettingsView()
            }
            .onAppear() {
                print("ChatListView appeared")
                print("Trying to load chats...")
                viewModel.loadChats()
                print("Loaded \(viewModel.chats.count) chats")
            }
        }
    }
}
