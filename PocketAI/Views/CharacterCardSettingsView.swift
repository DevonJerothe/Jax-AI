import SwiftUI
import PhotosUI
import UIKit

struct CharacterCardSettingsView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(ServiceContainer.self) private var serviceContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var appTheme
    @State private var characterCard: CharacterCardModel
    @State private var setPrivate: Bool

    @State private var selectedImage: PhotosPickerItem?
    @State private var descriptionPreviewExpanded = false
    @State private var descriptionExpanded = false
    @State private var personalityExpanded = false
    @State private var scenarioExpanded = false
    @State private var firstMessageExpanded = false
    @State private var altGreetingsExpanded = false
    @State private var configuredInitialExpansion = false
    @FocusState private var focusedField: FocusedField?

    private let characterID: UUID?
    private let dismissOnSave: Bool
    private let navigateToCharacterListOnSave: Bool
    var isNew: Bool = false

    private enum FocusedField: Hashable {
        case name
        case descriptionPreview
        case description
        case personality
        case scenario
        case firstMessage
        case altGreeting(Int)
    }

    private var shouldHidePrivateContent: Bool {
        serviceContainer.getConnectionStatusManager().connectionSettings.locked && characterCard.isPrivate
    }

    init(
        characterID: UUID? = nil,
        characterCard: CharacterCardModel = CharacterCardModel(),
        isNew: Bool = false,
        dismissOnSave: Bool = false,
        navigateToCharacterListOnSave: Bool = false
    ) {
        self.characterID = characterID
        self.dismissOnSave = dismissOnSave
        self.navigateToCharacterListOnSave = navigateToCharacterListOnSave
        _characterCard = State(initialValue: characterCard)
        _setPrivate = State(initialValue: characterCard.isPrivate)
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
        ScrollViewReader { proxy in
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

                        VStack(alignment: .leading) {
                            Text("Name")
                                .foregroundColor(appTheme.primaryText.color)

                            TextField(
                                "Name",
                                text: Binding(
                                    get: { characterCard.name ?? "" },
                                    set: { characterCard.name = $0 }
                                )
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .name)
                            .styledFormField()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .id(FocusedField.name)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Toggle(isOn: $setPrivate) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private Character")
                                .foregroundColor(appTheme.primaryText.color)

                            Text("Hide this character while the app is locked.")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }
                    .padding()
                    .background(appTheme.secondaryBackgroundColor.color)
                    .cornerRadius(12)
                    .tint(appTheme.tintColor.color)
                    .padding(.horizontal, 16)

                    collapsibleField(
                        title: "Description Preview",
                        text: Binding(
                            get: { characterCard.cardTagline ?? "" },
                            set: { characterCard.cardTagline = $0 }
                        ),
                        isExpanded: $descriptionPreviewExpanded,
                        field: .descriptionPreview
                    )

                    collapsibleEditor(
                        title: "Description",
                        placeholder: "Detailed description of the character...",
                        text: Binding(
                            get: { characterCard.description ?? "" },
                            set: { characterCard.description = $0 }
                        ),
                        isExpanded: $descriptionExpanded,
                        field: .description
                    )

                    collapsibleEditor(
                        title: "Personality",
                        placeholder: "The character's personality and traits...",
                        text: Binding(
                            get: { characterCard.personality ?? "" },
                            set: { characterCard.personality = $0 }
                        ),
                        isExpanded: $personalityExpanded,
                        field: .personality
                    )

                    collapsibleEditor(
                        title: "Scenario",
                        placeholder: "The setting or situation...",
                        text: Binding(
                            get: { characterCard.scenario ?? "" },
                            set: { characterCard.scenario = $0 }
                        ),
                        isExpanded: $scenarioExpanded,
                        field: .scenario
                    )

                    collapsibleEditor(
                        title: "First Message",
                        placeholder: "The first message to kick off the conversation...",
                        text: Binding(
                            get: { characterCard.firstMessage ?? "" },
                            set: { characterCard.firstMessage = $0 }
                        ),
                        isExpanded: $firstMessageExpanded,
                        field: .firstMessage
                    )

                    altGreetingsSection
                }
                .padding(.bottom, 24)
            }
            .onChange(of: focusedField) { _, field in
                scrollFocusedFieldIntoView(field, proxy: proxy)
            }
        }
        .navigationTitle(characterCard.name ?? "New Character")
        .background(appTheme.backgroundColor.color)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        do {
                            characterCard.isPrivate = setPrivate
                            try await ServiceContainer.shared.getCharacterStore().saveCharacterCard(characterCard)
                            focusedField = nil
                            UIApplication.shared.endEditing()
                            if navigateToCharacterListOnSave {
                                navManager.navigateToCharacterCards()
                            } else if dismissOnSave {
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
            setPrivate = storedCharacter.isPrivate
        
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
        isExpanded: Binding<Bool>,
        field: FocusedField
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            TextField(title, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: field)
                .styledFormField()
                .padding(.top, 8)
        } label: {
            Text(title)
                .foregroundColor(appTheme.primaryText.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .id(field)
    }

    @ViewBuilder
    private func collapsibleEditor(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isExpanded: Binding<Bool>,
        field: FocusedField
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            settingsTextEditor(
                text: text,
                placeholder: placeholder,
                field: field,
                height: 220
            )
            .padding(.top, 8)
        } label: {
            Text(title)
                .foregroundColor(appTheme.primaryText.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .id(field)
    }

    private var altGreetingsSection: some View {
        DisclosureGroup(isExpanded: $altGreetingsExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array((characterCard.altGreetings ?? []).indices), id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Greeting \(index + 1)")
                                .font(.subheadline)
                                .foregroundStyle(appTheme.secondaryText.color)

                            Spacer()

                            Button(role: .destructive) {
                                characterCard.altGreetings?.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }

                        settingsTextEditor(
                            text: altGreetingBinding(at: index),
                            placeholder: "Alternate opening message...",
                            field: .altGreeting(index),
                            height: 160
                        )
                    }
                    .id(FocusedField.altGreeting(index))
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
                .foregroundStyle(appTheme.tintColor.color)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            .padding(.top, 8)
        } label: {
            Text("Alternate Greetings")
                .foregroundColor(appTheme.primaryText.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func settingsTextEditor(
        text: Binding<String>,
        placeholder: String,
        field: FocusedField,
        height: CGFloat
    ) -> some View {
        EnhancedTextEditor(
            text: text,
            placeholder: placeholder,
            maxHeight: height,
            minHeight: height,
            textColor: UIColor(appTheme.primaryText.color),
            placeholderColor: UIColor(appTheme.secondaryText.color)
        )
        .focused($focusedField, equals: field)
        .frame(height: height)
        .foregroundStyle(appTheme.primaryText.color)
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func scrollFocusedFieldIntoView(_ field: FocusedField?, proxy: ScrollViewProxy) {
        guard let field else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
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
