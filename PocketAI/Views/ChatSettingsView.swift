//
//  ChatSettingsView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/12/25.
//

import SwiftUI
import Collections

struct ChatSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationManager.self) var navManager
    @Environment(ServiceContainer.self) private var serviceContainer

    @State private var viewModel: ChatViewModel
    @State private var characterCard: CharacterCardModel
    @State private var chatIsPrivate: Bool
    @State private var isDragging: Bool = false 

    private var connectionManager: ConnectionStatusManager {
        serviceContainer.getConnectionStatusManager()
    }

    init(chatID: UUID) {
        let viewModel = ChatViewModel(chatID: chatID)
        _viewModel = State(initialValue: viewModel)

        /// TODO: we need to make sure that if we cant load the character card, we hide the section that uses it. 
        /// We should never be on this screen with no active character card. 
        _characterCard = State(initialValue: viewModel.model?.getCharacterCard() ?? CharacterCardModel())
        _chatIsPrivate = State(initialValue: viewModel.model?.isPrivate ?? false)
    }

    private var responseLengthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(connectionManager.connectionSettings.responseLength ?? 300) },
            set: { connectionManager.update(\.responseLength, to: Int($0)) }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding<Double>(
            get: { connectionManager.connectionSettings.temperature ?? 0.6 },
            set: { connectionManager.update(\.temperature, to: $0) }
        )
    }

    private var userTemplatesBinding: Binding<OrderedDictionary<String, TemplateModel>> {
        Binding<OrderedDictionary<String, TemplateModel>>(
            get: { connectionManager.connectionSettings.userTemplates },
            set: { connectionManager.update(\.userTemplates, to: $0) }
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

                // Sampler Settings
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(temperatureBinding.wrappedValue)")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    Slider(value: temperatureBinding, in: 0.1...2.0, step: 0.05)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                VStack{
                    // Force Thinking Toggle
                    Toggle(isOn: Binding(
                        get: { connectionManager.connectionSettings.forceThinking },
                        set: { connectionManager.update(\.forceThinking, to: $0) }
                    )) {
                        Text("Force Thinking")
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)

                    Text("You may find if the model does not close the </think> tag, the response does not stream. It should still load when complete.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)

                // MARK: - Chat Settings which really is just the character card
                HStack {
                    Text("Card Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary) 
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)

                Toggle(isOn: $chatIsPrivate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Chat")
                            .foregroundColor(.primary)

                        Text("Hide this chat while the app is locked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack {
                    AvatarImage(image: characterCard.getAvatarImg(), size: 50)
                        .padding(.trailing, 12)

                    VStack(alignment: .leading) {
                        Text(characterCard.name ?? "")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary) 

                        Text(characterCard.cardTagline ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .onTapGesture {
                    navManager.navigateToCharacter(characterID: characterCard.id, keepCurrentPath: true)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Template Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary) 
                        Spacer()

                        Button(action: {
                            navManager.showNewTemplateView()
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.primary)
                                .font(.title2)
                        }
                    }

                    Text("Templates can be used to set instructions on how the model should responed and in what format / style. This will be added to the memory and used for every message.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if userTemplatesBinding.wrappedValue.count > 0 {
                    TemplateEditor(
                        isDragging: $isDragging,
                        userTemplates: userTemplatesBinding
                    )
                } else {
                    HStack {
                        Spacer() 
                        Text("No templates added.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer() 
                    }
                    .padding(.vertical, 24)
                }

                // Mark: - Clear Chat Button 
                HStack {
                    Button(action: {
                        Task {
                            await viewModel.clearChat()
                        }
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
                        Task {
                            await viewModel.updateChatSettings(
                                characterCard: characterCard,
                                isPrivate: chatIsPrivate
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            if let card = viewModel.fetchCharacterCard() {
                self.characterCard = card
            }
            self.chatIsPrivate = viewModel.model?.isPrivate ?? false
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .scrollDisabled(isDragging)
    }
}
