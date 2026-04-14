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
    var viewModel: ChatViewModel

    @State private var characterCard: CharacterCardModel
    @State private var isDragging: Bool = false 

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

    private var temperatureBinding: Binding<Double> {
        Binding<Double>(
            get: { ServiceContainer.shared.connectionSettings.temperature ?? 0.6 },
            set: { ServiceContainer.shared.connectionSettings.temperature = $0 }
        )
    }

    private var userTemplatesBinding: Binding<OrderedDictionary<String, TemplateModel>> {
        Binding<OrderedDictionary<String, TemplateModel>>(
            get: { ServiceContainer.shared.connectionSettings.userTemplates },
            set: { ServiceContainer.shared.connectionSettings.userTemplates = $0 }
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
                        get: { ServiceContainer.shared.connectionSettings.forceThinking },
                        set: { ServiceContainer.shared.connectionSettings.forceThinking = $0 }
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
                    navManager.navigateToCharacter(character: characterCard, keepCurrentPath: true)
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
        .onAppear {
            if let card = viewModel.fetchCharacterCard() {
                self.characterCard = card
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .scrollDisabled(isDragging)
    }
}
