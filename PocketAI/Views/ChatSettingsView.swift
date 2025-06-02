//
//  ChatSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/12/25.
//

import SwiftUI

struct ChatSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: ChatViewModel

    @State private var botDescription: String
    @State private var initialMessage: String
    @State private var chatName: String

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        _botDescription = State(initialValue: viewModel.model.characterCard.description ?? "" )
        _initialMessage = State(initialValue: viewModel.model.characterCard.firstMessage ?? "")
        _chatName = State(initialValue: viewModel.model.characterCard.name ?? "" )
    }

    var body: some View {
        NavigationStack {
            Form {
                
                Section {
                    TextField("Chat Name", text: $chatName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Chat Name")
                }
                
                Section {
                    ZStack(alignment: .topLeading) {
                        if botDescription.isEmpty {
                            Text("Enter a Description...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        
                        TextEditor(text: $botDescription)
                            .frame(minHeight: 300, maxHeight: 300)
                            // .fixedSize(horizontal: false, vertical: true)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("Description")
                } footer: {
                    Text("Instructions for how the AI should behave throughout the conversation.")
                }
                
                Section {
                    ZStack(alignment: .topLeading) {
                        if initialMessage.isEmpty {
                            Text("Enter your first message...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        
                        TextEditor(text: $initialMessage)
                            .frame(minHeight: 300, maxHeight: 300)
                            // .fixedSize(horizontal: false, vertical: true)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("Initial Message")
                } footer: {
                    Text("The first message to send to the AI.")
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("clear Chat") {
                        viewModel.clearChat()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.updateChatSettings(
                            chatName: chatName,
                            description: botDescription,
                            firstMessage: initialMessage
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
