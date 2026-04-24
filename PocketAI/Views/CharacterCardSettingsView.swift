import SwiftUI
import PhotosUI

struct CharacterCardSettingsView: View {
    @Environment(NavigationManager.self) var navManager
    @State private var characterCard: CharacterCardModel

    @State private var selectedImage: PhotosPickerItem?

    private let characterID: UUID?
    var isNew: Bool = false

    init(characterID: UUID? = nil, characterCard: CharacterCardModel = CharacterCardModel(), isNew: Bool = false) {
        self.characterID = characterID
        _characterCard = State(initialValue: characterCard)
        self.isNew = isNew
    }

    var body: some View {
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

                FormField(
                    title: "Description Preview", 
                    textBinding: Binding(
                        get: { characterCard.cardTagline ?? "" },
                        set: { characterCard.cardTagline = $0 }
                    )
                )

                FormEditor(
                    title: "Description", 
                    placeholder: "Detailed description of the character...",
                    textBinding: Binding(
                        get: { characterCard.description ?? "" },
                        set: { characterCard.description = $0 }
                    )
                )

                FormEditor(
                    title: "Personality", 
                    placeholder: "The character's personality and traits...",
                    textBinding: Binding(
                        get: { characterCard.personality ?? "" },
                        set: { characterCard.personality = $0 }
                    )
                )

                FormEditor(
                    title: "Scenario", 
                    placeholder: "The setting or situation...",
                    textBinding: Binding(
                        get: { characterCard.scenario ?? "" },
                        set: { characterCard.scenario = $0 }
                    )
                )

                FormEditor(
                    title: "First Message", 
                    placeholder: "The first message to kick off the conversation...",
                    textBinding: Binding(
                        get: { characterCard.firstMessage ?? "" },
                        set: { characterCard.firstMessage = $0 }
                    )
                )
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
                            navManager.popBack()
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
        }
        .onChange(of: selectedImage) {
            Task {
                if let data = try? await selectedImage?.loadTransferable(type: Data.self) {
                    characterCard.imageData = data
                }
            }
        }
    }
}
