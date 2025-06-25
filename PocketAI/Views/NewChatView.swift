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

    var createCharacterCard: Bool
    
    init(createCharacterCard: Bool = false) {
        self.createCharacterCard = createCharacterCard
    }

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
                    if createCharacterCard, let _ = viewModel.createCharacterCard(type: selectedTab) {
                        navManager.popBack()
                    } else {
                        if let newChat = viewModel.createChat(type: selectedTab) {
                            navManager.navigateToChat(chat: newChat)
                        }
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
                    // if viewModel.imgData == nil {
                    //     Image(systemName: "person.circle.fill")
                    //         .resizable()
                    //         .aspectRatio(contentMode: .fill)
                    //         .frame(width: 80, height: 80)
                    //         .foregroundColor(.gray)
                    //         .clipShape(Circle())
                    // } else {
                    //     Image(uiImage: UIImage(data: viewModel.imgData!)!)
                    //         .resizable()
                    //         .aspectRatio(contentMode: .fill)
                    //         .frame(width: 80, height: 80)
                    //         .clipShape(Circle())
                    // }
                    AvatarImage(image: viewModel.getAvatarImg(), size: 80)
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

            FormField(title: "Chat Name", textBinding: $viewModel.chatName)

            FormEditor(
                title: "System Prompt",
                placeholder: "Instructions for how the AI should behave throughout the conversation...",
                textBinding: $viewModel.systemPrompt
            )   

            FormEditor(
                title: "Initial Message",
                placeholder: "The first message to send to the AI...",
                textBinding: $viewModel.initialMessage
            )
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
}
