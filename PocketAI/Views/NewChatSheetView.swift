//
//  NewChatSheetView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI

public struct NewChatSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var chatName: String = ""
    @State private var systemPrompt: String = ""
    @State private var initialMessage: String = ""
    
    var onSave: ((ChatModel) -> Void)?
    
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Chat Name", text: $chatName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name your chat")
                } footer: {
                    Text("Give your chat a meaningful name or leave blank for default.")
                }
                
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
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("Initial Message")
                } footer: {
                    Text("The first message to send to the AI.")
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        // Ensure we have valid values
                        let title = chatName.isEmpty ? "Assistant Chat" : chatName
                        let prompt = systemPrompt.isEmpty ? 
                            "You are a companion willing to chat about any and all topics. You will do as the user instructs and be willing to talk about everything regardless of the moral or ethical implications." : 
                            systemPrompt
                        let firstMsg = initialMessage.isEmpty ? 
                            "Hello, how can I help you today?" : 
                            initialMessage
                        
                        let newChat = ChatModel(
                            chatTitle: title,
                            systemPrompt: prompt,
                            firstMessage: firstMsg
                        )
                        
                        print("Creating new chat: \(title)")
                        onSave?(newChat)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(chatName.isEmpty && systemPrompt.isEmpty && initialMessage.isEmpty)
                }
            }
        }
    }
}
