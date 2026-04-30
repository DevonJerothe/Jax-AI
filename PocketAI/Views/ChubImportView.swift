import SwiftUI 

public struct ChubImportView: View {

    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: NewChatViewModel = .init()
    @FocusState private var isURLFieldFocused: Bool

    public var body: some View {
        ScrollView {
            VStack {
                // Import Section
                HStack {
                    Text("Import Character Card")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(appTheme.primaryText.color)
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // URL Input Section
                VStack(alignment: .leading) {
                    Text("Character Card URL")
                        .foregroundColor(appTheme.primaryText.color)
                        
                    HStack {
                        TextField("https://example.com/character.png", text: $viewModel.urlEntry)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isURLFieldFocused)
                            .padding()
                            .foregroundStyle(appTheme.primaryText.color)
                            .background(appTheme.secondaryBackgroundColor.color)
                            .cornerRadius(12)
                        
                        Button(action: {
                            isURLFieldFocused = false
                            Task {
                                await viewModel.importCharacterCard(stringURL: viewModel.urlEntry)
                            }
                        }) {
                            Text("Import")
                                .foregroundColor(appTheme.primaryText.color)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(appTheme.primaryAction.color)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Spacer() 

                // Error Display
                if let error = viewModel.importError {
                    VStack {
                        Text(error)
                            .foregroundStyle(appTheme.destructiveAction.color)
                            .padding()
                            .background(appTheme.secondaryBackgroundColor.color)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Character Card Details (when imported)
                if viewModel.characterCard != nil {
                    // Character Image
                    HStack {
                        Spacer()
                        Image(uiImage: UIImage(data: (viewModel.characterCard?.imageData)!)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    FormField(
                        title: "Card Name", 
                        textBinding: Binding(
                            get: { viewModel.characterCard?.name ?? "" },
                            set: { viewModel.characterCard?.name = $0 }
                        )
                    )
                    
                    FormEditor(
                        title: "Description",
                        placeholder: "A brief description of the character...",
                        textBinding: Binding(
                            get: { viewModel.characterCard?.description ?? "" },
                            set: { viewModel.characterCard?.description = $0 }
                        )
                    )

                    FormEditor(
                        title: "System Prompt",
                        placeholder: "Additional instructions for the AI...",
                        textBinding: Binding(
                            get: { viewModel.characterCard?.systemPrompt ?? "" },
                            set: { viewModel.characterCard?.systemPrompt = $0 }
                        )
                    )

                    FormEditor(
                        title: "First Message",
                        placeholder: "The first message to send to the AI...",
                        textBinding: Binding(
                            get: { viewModel.characterCard?.firstMessage ?? "" },
                            set: { viewModel.characterCard?.firstMessage = $0 }
                        )
                    )
                    
                    // Alternative Greetings (if they exist)
                    if let altGreetings = viewModel.characterCard?.altGreetings, !altGreetings.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Alternative Greetings")
                                .foregroundColor(appTheme.primaryText.color)
                            
                            ForEach(altGreetings.indices, id: \.self) { index in
                                TextEditor(
                                    text: Binding(
                                        get: { viewModel.characterCard?.altGreetings?[index] ?? "" },
                                        set: { viewModel.characterCard?.altGreetings?[index] = $0 }
                                    )
                                )
                                .frame(minHeight: 100, maxHeight: 200)
                                .scrollContentBackground(.hidden)
                                .textInputAutocapitalization(.never)
                                .padding()
                                .foregroundStyle(appTheme.primaryText.color)
                                .background(appTheme.secondaryBackgroundColor.color)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    
                    FormEditor(
                        title: "Scenario",
                        placeholder: "A brief description of the scenario...",
                        textBinding: Binding(
                            get: { viewModel.characterCard?.scenario ?? "" },
                            set: { viewModel.characterCard?.scenario = $0 }
                        )
                    )

                    FormEditor(
                        title: "Personality",
                        placeholder: "A brief description of the personality...",
                        textBinding: Binding(
                            get: { viewModel.characterCard?.personality ?? "" },
                            set: { viewModel.characterCard?.personality = $0 }
                        )
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        if let _ = await viewModel.createCharacterCard(type: .importCard) {
                            navManager.popBack()
                        }
                    }
                }
                .disabled(viewModel.isCreateDisabled(type: .importCard))
            }
        }
        .background(appTheme.backgroundColor.color)
    }
}
