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
                ChatViewHeader(
                    leadingButtonIcon: connectionManager.isConnected ? "network" : "network.slash",
                    leadingIconColor: connectionManager.isConnected ? .green : .red,
                    trailingButtonIcon: "plus",
                    leadingButtonAction: {
                        Task {
                            // await viewModel.connect("192.168.68.56", 8000)
//                          await viewModel.connect("g1cb8bg7kvual6-5001.proxy.runpod.net", 443)
                            viewModel.showConnectionSheet.toggle()
                        }
                    },
                    trailingButtonAction: {
                        viewModel.showNewChatSheet.toggle()
                    }
                )

                // List with swipe actions
                List {
                    ForEach(viewModel.chats, id: \.id) { chat in
                        ZStack {
                            // Background and border as a single unit
                            Rectangle()
                                .fill(Color(UIColor.systemGray5))
                                .overlay(
                                    Rectangle()
                                        .stroke(.white, lineWidth: 0.5)
                                )
                            
                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chat.chatTitle)
                                    .fontWeight(.medium)
                                Text(chat.messages.last?.text ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding()
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
                        .listRowBackground(Color.clear)
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
//                print("Database path: \(try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("pocketai.sqlite").path)")
                print("Trying to load chats...")
                viewModel.loadChats()
                print("Loaded \(viewModel.chats.count) chats")
            }
            .navigationBarHidden(true) // Hiding the standard navigation bar since we're using a custom header
        }
        .environment(navManager) // Use environment instead of environmentObject
    }
}
