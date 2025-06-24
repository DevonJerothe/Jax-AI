import SwiftUI
import PhotosUI

public enum NewChatTab: String, CaseIterable, Identifiable {
    case manual = "Create Manually"
    case importCard = "Import Card"

    public var id: String { self.rawValue }
}

public struct NewChatView: View {
    @Environment(NavigationManager.self) var navManager

    @State private var viewModel: NewChatViewModel = .init()
    @State private var selectedTab: NewChatTab = .manual
    
    // Photo info for manual chat
    @State private var selectedImage: PhotosPickerItem?
    @FocusState private var isURLFieldFocused: Bool

    public var body: some View {
        ScrollView {
            VStack {
                // Tab Picker
                VStack {
                    Picker("New Chat Type", selection: $selectedTab) {
                        ForEach(NewChatTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 5)
                }

                if selectedTab == .manual {
                    buildManualChatView
                } else {
                    buildImporterView
                }
            }
        }
        .navigationTitle("New Chat") 
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Create") {
                    if let newChat = viewModel.createChat(type: selectedTab) {
                        navManager.navigateToChat(chat: newChat)
                    }
                }
                .fontWeight(.bold)
                .disabled(viewModel.isCreateDisabled(type: selectedTab))
            }
        }
    }
    
    @ViewBuilder
    private var buildManualChatView: some View {
        VStack {
            // Avatar Selection Section
            HStack {
                Text("Avatar")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Avatar Image Picker
            HStack {
                Spacer()
                PhotosPicker(
                    selection: $selectedImage,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    if viewModel.imgData == nil {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                            .clipShape(Circle())
                    } else {
                        Image(uiImage: UIImage(data: viewModel.imgData!)!)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .onChange(of: selectedImage) {
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self) {
                        viewModel.imgData = data
                    }
                }
            }

            // Chat Name Section
            VStack(alignment: .leading) {
                Text("Chat Name")
                    .foregroundColor(.primary)
                    
                TextField("Chat Name", text: $viewModel.chatName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // System Prompt Section
            VStack(alignment: .leading) {
                Text("System Prompt")
                    .foregroundColor(.primary)
                    
                ZStack(alignment: .topLeading) {
                    if viewModel.systemPrompt.isEmpty {
                        Text("Instructions for how the AI should behave throughout the conversation...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    TextEditor(text: $viewModel.systemPrompt)
                        .frame(minHeight: 75, maxHeight: 300)
                        .scrollContentBackground(.hidden)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Initial Message Section
            VStack(alignment: .leading) {
                Text("Initial Message")
                    .foregroundColor(.primary)
                    
                ZStack(alignment: .topLeading) {
                    if viewModel.initialMessage.isEmpty {
                        Text("The first message to send to the AI...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    TextEditor(text: $viewModel.initialMessage)
                        .frame(minHeight: 150, maxHeight: 300)
                        .scrollContentBackground(.hidden)
                        .textInputAutocapitalization(.never)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var buildImporterView: some View {
        VStack {
            // Import Section
            HStack {
                Text("Import Character Card")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // URL Input Section
            VStack(alignment: .leading) {
                Text("Character Card URL")
                    .foregroundColor(.primary)
                    
                HStack {
                    TextField("https://example.com/character.png", text: $viewModel.urlEntry)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .focused($isURLFieldFocused)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(12)
                    
                    Button(action: {
                        isURLFieldFocused = false
                        Task {
                            await viewModel.importCharacterCard(stringURL: viewModel.urlEntry)
                        }
                    }) {
                        Text("Import")
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.secondary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Error Display
            if let error = viewModel.importError {
                VStack {
                    Text(error)
                        .foregroundStyle(Color.red)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.6))
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
                
                // Card Name
                VStack(alignment: .leading) {
                    Text("Card Name")
                        .foregroundColor(.primary)
                        
                    TextField(
                        "Card Name", 
                        text: Binding(
                            get: { viewModel.characterCard?.name ?? "" },
                            set: { viewModel.characterCard?.name = $0 }
                        )
                    )
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
                            get: { viewModel.characterCard?.description ?? "" },
                            set: { viewModel.characterCard?.description = $0 }
                        )
                    )
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // System Prompt (if exists)
                if (viewModel.characterCard?.systemPrompt) != nil {
                    VStack(alignment: .leading) {
                        Text("System Prompt")
                            .foregroundColor(.primary)
                            
                        TextEditor(
                            text: Binding(
                                get: { viewModel.characterCard?.systemPrompt ?? "" },
                                set: { viewModel.characterCard?.systemPrompt = $0 }
                            )
                        )
                        .frame(minHeight: 100, maxHeight: 200)
                        .scrollContentBackground(.hidden)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                
                // First Message
                VStack(alignment: .leading) {
                    Text("First Message")
                        .foregroundColor(.primary)
                        
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.firstMessage ?? "" },
                            set: { viewModel.characterCard?.firstMessage = $0 }
                        )
                    )
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Alternative Greetings (if they exist)
                if let altGreetings = viewModel.characterCard?.altGreetings, !altGreetings.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Alternative Greetings")
                            .foregroundColor(.primary)
                        
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
                            .background(Color(.systemGray6).opacity(0.6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                
                // Scenario
                VStack(alignment: .leading) {
                    Text("Scenario")
                        .foregroundColor(.primary)
                        
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.scenario ?? "" },
                            set: { viewModel.characterCard?.scenario = $0}
                        )
                    )
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Personality
                VStack(alignment: .leading) {
                    Text("Personality")
                        .foregroundColor(.primary)
                        
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.personality ?? "" },
                            set: { viewModel.characterCard?.personality = $0 }
                        )
                    )
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}