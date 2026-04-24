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
                    Text("Character Hub import is available from the Characters tab.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                } else {
                    Text("Import cards from the Characters tab.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
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
                    Task {
                        if createCharacterCard, let _ = await viewModel.createCharacterCard(type: selectedTab) {
                            navManager.popBack()
                        } else if let newChat = await viewModel.createChat(type: selectedTab) {
                            navManager.navigateToChat(chatID: newChat.id)
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
}
