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

    @State private var characterCard: CharacterCardModel

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel

        _characterCard = State(initialValue: viewModel.model.getCharacterCard())
    }

    private var responseLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(ServiceContainer.shared.connectionSettings.responseLength ?? 300) },
            set: { ServiceContainer.shared.connectionSettings.responseLength = Int($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack {

                // MARK: - Connection Related Settings
                // this will change the connections settings for the app and all chats
                // potentially we could have a per chat connection settings option
                HStack {
                    Text("Model Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary) 
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Response Length Slider 
                VStack(alignment: .leading) {
                    HStack {
                        Text("Response Length")
                            .foregroundColor(.primary)
                        Spacer() 
                        Text("\(Int(responseLengthBinding.wrappedValue))")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    Slider(value: responseLengthBinding, in: 120...3000, step: 60)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                // MARK: - Chat Settings which really is just the character card
                HStack {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary) 
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)

                // Chat Name (char name) 
                VStack(alignment: .leading) {
                    Text("Chat Name")
                        .foregroundColor(.primary)
                        
                    TextField(
                            "Chat Name",
                            text: Binding(
                                get: { characterCard.name ?? "" },
                                set: { characterCard.name = $0 }
                            )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Description 
                VStack(alignment: .leading) {
                    Text("Description")
                        .foregroundColor(.primary)
                        
                    TextEditor(
                            text: Binding(
                                get: { characterCard.description ?? "" },
                                set: { characterCard.description = $0 }
                            )
                        )
                        .frame(minHeight: 75, maxHeight: 300)
                        .scrollContentBackground(.hidden)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // First Message 
                VStack(alignment: .leading) {
                    Text("First Message")
                        .foregroundColor(.primary)
                        
                    TextEditor(
                        text: Binding(
                            get: { characterCard.firstMessage ?? "" },
                            set: { characterCard.firstMessage = $0 }
                        )
                    )
                    .frame(minHeight: 75, maxHeight: 300)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Mark: - Clear Chat Button 
                HStack {
                    Button(action: {
                        viewModel.clearChat()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Chat")
                        }
                        .foregroundColor(.red)
                        .padding()
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Save Button 
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.updateChatSettings(
                            characterCard: characterCard
                        ) 
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
    }
}
