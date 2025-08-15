import SwiftUI
import PhotosUI

public enum NewChatTab: String, CaseIterable, Identifiable {
    case manual = "Create Manually"
    case charHub = "Character Hub"
    case importCard = "Import Card"

    public var id: String { self.rawValue }
}

public struct NewChatView: View {
    @Environment(NavigationManager.self) var navManager

    @State private var viewModel: NewChatViewModel = .init()
    @State private var charHubViewModel: CharHubViewModel = .init()
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
                } else if selectedTab == .charHub {
                    buildCharHubView
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
    private var buildCharHubView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                TextField("Search characters...", text: $charHubViewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                    .onSubmit {
                        Task { await charHubViewModel.searchCharacters(query: charHubViewModel.searchQuery, page: 1, count: charHubViewModel.searchCount) }
                    }
                
                Button("Search") {
                    Task { await charHubViewModel.searchCharacters(query: charHubViewModel.searchQuery, page: 1, count: charHubViewModel.searchCount) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.secondary)
                .foregroundStyle(.primary)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Results grid with infinite scroll
            if charHubViewModel.searchResults.isEmpty == false {
                CharHubResultsGrid(
                    viewModel: charHubViewModel,
                    loadMore: {
                        await charHubViewModel.loadNextPageIfPossible()
                    }
                )
            } else if charHubViewModel.isLoading {
                LoadingIndicator(size: 30)
            } else if charHubViewModel.searchQuery.isEmpty == false {
                Spacer()
                Text("No Results Found...")
                Spacer()
            } else {
                Spacer()
                Text("Search The Hub!")
            }
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

// MARK: - CharHub subviews

struct CharHubResultsGrid: View {
    @Environment(NavigationManager.self) var navManager
    @Bindable var viewModel: CharHubViewModel
    let loadMore: () async -> Void
    @State private var lastTriggerIndex: Int = -1
    @State private var allowTrigger: Bool = true
    @State private var hasScrolledDown: Bool = false

    private let columns: [GridItem] = [
        GridItem(.flexible(maximum: 200), spacing: 16),
        GridItem(.flexible(maximum: 200), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { index, item in
                    CharHubCardPreview(card: item)
                        .onTapGesture {
                            Task {
                                let success = await viewModel.getCharacter(card: item)
                                if success {
                                    navManager.popBack()
                                }
                            }
                        }
                }
                
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                            let screenHeight = UIScreen.main.bounds.height
                            if newValue < screenHeight {
                                Task {
                                    await loadMore()
                                }
                            }
                        }
                }

                // Loading/empty states
                if viewModel.isLoading && viewModel.searchPage > 1 {
                    HStack { Spacer() ; LoadingIndicator(size: 30) ; Spacer() }
                        .padding(.vertical, 12)
                        .gridCellColumns(2)
                }
            }
            .padding()
        }
    }
}

struct CharHubCardPreview: View {
    let card: CharHubModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thubmnailURL = card.thumbnail {
                AsyncImage(url: thubmnailURL) { state in
                    switch state {
                    case .empty:
                        HStack {
                            Spacer()
                            LoadingIndicator(size: 30)
                                .frame(height: 150)
                            Spacer()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .frame(maxWidth: 195)
                            .clipped()
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                            )
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(card.tagline ?? card.description ?? "No description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                Spacer()
                
                HStack {
                    Text(card.source ?? "unknown")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundStyle(.secondary)
                        Text("\(card.metadata?.totalTokens ?? 0)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct CharHubScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
