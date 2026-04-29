import SwiftUI
import PhotosUI

struct CharacterCardSettingsView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.dismiss) private var dismiss
    @State private var characterCard: CharacterCardModel

    @State private var selectedImage: PhotosPickerItem?
    @State private var descriptionPreviewExpanded = false
    @State private var descriptionExpanded = false
    @State private var personalityExpanded = false
    @State private var scenarioExpanded = false
    @State private var firstMessageExpanded = false
    @State private var altGreetingsExpanded = false
    @State private var configuredInitialExpansion = false

    private let characterID: UUID?
    private let dismissOnSave: Bool
    var isNew: Bool = false

    private var shouldHidePrivateContent: Bool {
        serviceContainer.getConnectionStatusManager().connectionSettings.locked && characterCard.isPrivate
    }

    init(
        characterID: UUID? = nil,
        characterCard: CharacterCardModel = CharacterCardModel(),
        isNew: Bool = false,
        dismissOnSave: Bool = false
    ) {
        self.characterID = characterID
        self.dismissOnSave = dismissOnSave
        _characterCard = State(initialValue: characterCard)
        self.isNew = isNew
    }

    var body: some View {
        Group {
            if shouldHidePrivateContent {
                ContentUnavailableView(
                    "Private Character Locked",
                    systemImage: "lock.fill",
                    description: Text("Unlock the app in Settings to view this character.")
                )
            } else {
                settingsContent
            }
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack(alignment: .center) {

                    PhotosPicker(
                        selection: $selectedImage,
                        matching: .images, 
                        photoLibrary: .shared()
                    ) {
                        AvatarImage(image: characterCard.getAvatarImg(), size: 100)
                    }
                    .padding(.trailing, 12)

                    FormField(
                        title: "Name", 
                        textBinding: Binding(
                            get: { characterCard.name ?? "" },
                            set: { characterCard.name = $0 }
                        )
                    )
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Toggle(isOn: $characterCard.isPrivate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Character")
                            .foregroundColor(.primary)

                        Text("Hide this character while the app is locked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                collapsibleField(
                    title: "Description Preview",
                    text: Binding(
                        get: { characterCard.cardTagline ?? "" },
                        set: { characterCard.cardTagline = $0 }
                    ),
                    isExpanded: $descriptionPreviewExpanded
                )

                collapsibleEditor(
                    title: "Description",
                    placeholder: "Detailed description of the character...",
                    text: Binding(
                        get: { characterCard.description ?? "" },
                        set: { characterCard.description = $0 }
                    ),
                    isExpanded: $descriptionExpanded
                )

                collapsibleEditor(
                    title: "Personality",
                    placeholder: "The character's personality and traits...",
                    text: Binding(
                        get: { characterCard.personality ?? "" },
                        set: { characterCard.personality = $0 }
                    ),
                    isExpanded: $personalityExpanded
                )

                collapsibleEditor(
                    title: "Scenario",
                    placeholder: "The setting or situation...",
                    text: Binding(
                        get: { characterCard.scenario ?? "" },
                        set: { characterCard.scenario = $0 }
                    ),
                    isExpanded: $scenarioExpanded
                )

                collapsibleEditor(
                    title: "First Message",
                    placeholder: "The first message to kick off the conversation...",
                    text: Binding(
                        get: { characterCard.firstMessage ?? "" },
                        set: { characterCard.firstMessage = $0 }
                    ),
                    isExpanded: $firstMessageExpanded
                )

                altGreetingsSection
            }
        }
        .navigationTitle(characterCard.name ?? "New Character")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        do {
                            try await ServiceContainer.shared.getCharacterStore().saveCharacterCard(characterCard)
                            if dismissOnSave {
                                dismiss()
                            } else {
                                navManager.popBack()
                            }
                        } catch {
                            print("Failed to save character card: \(error)")
                        }
                    }
                }
            }
        }
        .onAppear {
            guard let characterID,
                let storedCharacter = ServiceContainer.shared.getCharacterStore().character(withID: characterID) else {
                return
            }

            characterCard = storedCharacter
            configureInitialExpansion()
        }
        .onAppear {
            configureInitialExpansion()
        }
        .onChange(of: selectedImage) {
            Task {
                if let data = try? await selectedImage?.loadTransferable(type: Data.self) {
                    characterCard.imageData = data
                }
            }
        }
    }

    @ViewBuilder
    private func collapsibleField(
        title: String,
        text: Binding<String>,
        isExpanded: Binding<Bool>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            TextField(title, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .styledFormField()
                .padding(.top, 8)
        } label: {
            Text(title)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func collapsibleEditor(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isExpanded: Binding<Bool>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }

                TextEditor(text: text)
                    .frame(height: 220)
                    .scrollContentBackground(.hidden)
            }
            .styledFormField()
            .padding(.top, 8)
        } label: {
            Text(title)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var altGreetingsSection: some View {
        DisclosureGroup(isExpanded: $altGreetingsExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array((characterCard.altGreetings ?? []).indices), id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Greeting \(index + 1)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button(role: .destructive) {
                                characterCard.altGreetings?.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }

                        ZStack(alignment: .topLeading) {
                            if altGreetingBinding(at: index).wrappedValue.isEmpty {
                                Text("Alternate opening message...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }

                            TextEditor(text: altGreetingBinding(at: index))
                                .frame(height: 160)
                                .scrollContentBackground(.hidden)
                        }
                        .styledFormField()
                    }
                }

                Button {
                    var greetings = characterCard.altGreetings ?? []
                    greetings.append("")
                    characterCard.altGreetings = greetings
                    altGreetingsExpanded = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Add Alternate Greeting", systemImage: "plus")
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            .padding(.top, 8)
        } label: {
            Text("Alternate Greetings")
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func altGreetingBinding(at index: Int) -> Binding<String> {
        Binding {
            guard let greetings = characterCard.altGreetings, greetings.indices.contains(index) else {
                return ""
            }
            return greetings[index]
        } set: { value in
            var greetings = characterCard.altGreetings ?? []
            guard greetings.indices.contains(index) else { return }
            greetings[index] = value
            characterCard.altGreetings = greetings
        }
    }

    private func configureInitialExpansion() {
        guard configuredInitialExpansion == false else { return }

        descriptionPreviewExpanded = hasContent(characterCard.cardTagline)
        descriptionExpanded = hasContent(characterCard.description)
        personalityExpanded = hasContent(characterCard.personality)
        scenarioExpanded = hasContent(characterCard.scenario)
        firstMessageExpanded = hasContent(characterCard.firstMessage)
        altGreetingsExpanded = characterCard.altGreetings?.contains { hasContent($0) } ?? false
        configuredInitialExpansion = true
    }

    private func hasContent(_ string: String?) -> Bool {
        string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
