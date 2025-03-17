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

    var body: some View {
        NavigationStack {
            VStack {
                HStack(alignment: .center) {

                    Button(
                        action: {
                            Task {
                                await viewModel.connect("192.168.68.56", 8000)
                            }
                        },
                        label: {
                            HStack {
                                Image(
                                    systemName: viewModel.connected
                                        ? "network" : "network.slash"
                                )
                                .foregroundStyle(
                                    viewModel.connected ? .green : .red
                                )
                                .frame(width: 15, height: 15)
                                .padding(10)
                                .background(
                                    Circle()
                                        .stroke(
                                            viewModel.connected ? .green : .red,
                                            lineWidth: 0.5)
                                )
                            }
                        }
                    )

                    Spacer()
                    Text("PocketAI")
                    Spacer()
                    Button(
                        action: {
                            viewModel.showNewChatSheet.toggle()
                        },
                        label: {
                            Image(
                                systemName: "plus"
                            )
                            .foregroundStyle(.white)
                            .frame(width: 15, height: 15)
                            .padding(10)
                            .background(
                                Circle()
                                    .stroke(.white, lineWidth: 0.5)
                            )
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                Divider()
                    .frame(height: 0.5)
                    .overlay(.white)
                
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
                                destination: ChatView(chatModel: chat, llm: viewModel.llmClient))
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
            .onAppear() {
                print("ChatListView appeared")
                print("Database path: \(try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("pocketai.sqlite").path)")
                print("Trying to load chats...")
                viewModel.loadChats()
                print("Loaded \(viewModel.chats.count) chats")
            }
            .navigationBarHidden(true) // Hiding the standard navigation bar since we're using a custom header
        }
        .environment(navManager) // Use environment instead of environmentObject
    }
}
