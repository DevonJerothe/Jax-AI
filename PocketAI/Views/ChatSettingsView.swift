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

    @State private var systemPrompt: String
    @State private var initialMessage: String

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        _systemPrompt = State(initialValue: viewModel.model.memory)
        _initialMessage = State(initialValue: viewModel.model.firstMessage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        if systemPrompt.isEmpty {
                            Text("Enter a system prompt...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 100)
                            .fixedSize(horizontal: false, vertical: true)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("System Prompt")
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
                            .frame(minHeight: 100)
                            .fixedSize(horizontal: false, vertical: true)
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.updateChatSettings(
                            memory: systemPrompt,
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
