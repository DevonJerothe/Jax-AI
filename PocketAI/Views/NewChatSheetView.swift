//
//  NewChatSheetView.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import PhotosUI
import SwiftUI

public enum NewChatTab: String, CaseIterable, Identifiable {
    case manual = "Create Manually"
    case importCard = "Import Card"

    public var id: String { self.rawValue }
}

public struct NewChatSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: NewChatViewModel = .init()

    //Photo info
    @State private var selectedImage: PhotosPickerItem?

    @State private var selectedTab: NewChatTab = .manual
    @FocusState private var isURLFieldFocused: Bool

    var onSave: ((ChatModel) -> Void)?

    public var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Picker("New Chat Type", selection: $selectedTab) {
                        ForEach(NewChatTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }

                if selectedTab == .manual {
                    buildManualChatView
                } else {
                    buildImporterView
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
                        let newChat = viewModel.createChat(type: selectedTab)
                        onSave?(newChat)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(viewModel.isCreateDisabled(type: selectedTab))
                }
            }
        }
    }

    @ViewBuilder
    private var buildImporterView: some View {
        Form {
            Section {
                HStack {
                    TextField("CharacterCard URL", text: $viewModel.urlEntry)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .focused($isURLFieldFocused)
                    Spacer()
                    Button(
                        action: {
                            isURLFieldFocused = false
                            Task {
                                await viewModel.importCharacterCard(
                                    stringURL: viewModel.urlEntry)
                            }
                        },
                        label: {
                            Text("Import")
                        })
                }
            }

            if let error = viewModel.importError {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                    Spacer()
                }
            }

            if viewModel.characterCard != nil {
                HStack {
                    Spacer()
                    Image(
                        uiImage: UIImage(
                            data: (viewModel.characterCard?.imageData)!)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                Section {
                    TextField(
                        "Card Name", 
                        text: Binding(
                            get: { viewModel.characterCard?.name ?? "" },
                            set: { viewModel.characterCard?.name = $0 }
                        )
                    )
                } header: {
                    Text("Card Name")
                }
                
                Section {
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.description ?? "" },
                            set: { viewModel.characterCard?.description = $0 }
                        )
                    )
                    .frame(minHeight: 100)
                } header: {
                    Text("Description")
                }
                
                if (viewModel.characterCard?.systemPrompt) != nil {
                    Section {
                        TextEditor(
                            text: Binding(
                                get: { viewModel.characterCard?.systemPrompt ?? "" },
                                set: { viewModel.characterCard?.systemPrompt = $0 }
                            )
                        )
                        .frame(minHeight: 100)
                    } header: {
                        Text("System Prompt")
                    }
                }
                
                Section {
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.firstMessage ?? "" },
                            set: { viewModel.characterCard?.firstMessage = $0 }
                        )
                    )
                    .frame(minHeight: 100)
                } header: {
                    Text("First Message")
                }
                
                if let altGreetings = viewModel.characterCard?.altGreetings, altGreetings.isEmpty == false {
                    Section {
                        ForEach(altGreetings.indices, id: \.self) { index in
                            TextEditor(
                                text: Binding(
                                    get: { viewModel.characterCard?.altGreetings?[index] ?? "" },
                                    set: { viewModel.characterCard?.altGreetings?[index] = $0 }
                                )
                            )
                            .frame(minHeight: 100)
                            .padding()
                        }
                    } header: {
                        Text("Alternative Greetings")
                    }
                }
                
                Section {
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.scenario ?? "" },
                            set: { viewModel.characterCard?.scenario = $0}
                        )
                    )
                    .frame(minHeight: 100)
                } header: {
                    Text("Scenario")
                }
                
                Section {
                    TextEditor(
                        text: Binding(
                            get: { viewModel.characterCard?.personality ?? "" },
                            set: { viewModel.characterCard?.personality = $0 }
                        )
                    )
                    .frame(minHeight: 100)
                } header: {
                    Text("Personality")
                }
            }
        }
    }

    @ViewBuilder
    private var buildManualChatView: some View {
        Form {
            // Avatar image
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
            .listRowBackground(Color.clear)
            .onChange(
                of: selectedImage
            ) {
                Task {
                    if let data = try? await selectedImage?
                        .loadTransferable(type: Data.self)
                    {
                        viewModel.imgData = data
                    }
                }
            }

            Section {
                TextField("Chat Name", text: $viewModel.chatName)
                    .autocorrectionDisabled()
            } header: {
                Text("Name your chat")
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if viewModel.systemPrompt.isEmpty {
                        Text("Enter a system prompt...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    TextEditor(text: $viewModel.systemPrompt)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                }
            } header: {
                Text("System Prompt")
            } footer: {
                Text(
                    "Instructions for how the AI should behave throughout the conversation."
                )
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if viewModel.initialMessage.isEmpty {
                        Text("Enter your first message...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    TextEditor(text: $viewModel.initialMessage)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                }
            } header: {
                Text("Initial Message")
            } footer: {
                Text("The first message to send to the AI.")
            }
        }
    }
}
