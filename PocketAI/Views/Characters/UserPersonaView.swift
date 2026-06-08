import PhotosUI
import SwiftUI
import UIKit

struct UserPersonaView: View {
    @Environment(\.appTheme) private var appTheme
    @Environment(\.dismiss) private var dismiss
    @State private var editablePersona: UserPersonaModel?
    @State private var selectedImage: PhotosPickerItem?
    @FocusState private var focusedField: FocusedField?
    @State private var isNewPersona: Bool = false
    @State private var showUnsavedAlert: Bool = false

    private let personaStore: PersonaStore

    private enum FocusedField: Hashable {
        case name
        case description
    }

    private enum Layout {
        static let avatarSize: CGFloat = 100
        static let editorHeight: CGFloat = 220
        static let cornerRadius: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
    }

    init(personaStore: PersonaStore) {
        self.personaStore = personaStore
    }

    var body: some View {
        Group {
            if editablePersona == nil {
                ContentUnavailableView {
                    Label("No Active Persona", systemImage: "person.3.sequence")
                } description: {
                    Text("Create a new persona to get started")
                } actions: {
                    Button("Create Persona") {
                        editablePersona = UserPersonaModel(active: true)
                        isNewPersona = true
                    }
                }
            } else {
                settingsContent
            }
        }
        .navigationTitle(editablePersona?.name ?? "User Persona")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(appTheme.backgroundColor.color)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if isNewPersona {
                        showUnsavedAlert = true
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }

            if editablePersona != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        savePersona()
                    }
                }
            }
        }
        .alert("Unsaved Persona", isPresented: $showUnsavedAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have an unsaved new persona. Are you sure you want to discard it?")
        }
        .onAppear(perform: syncPersonaFromStore)
        .onChange(of: selectedImage) {
            Task {
                do {
                    if let data = try await selectedImage?.loadTransferable(type: Data.self) {
                        editablePersona?.imageData = data
                    }
                } catch {
                    print("Failed to load selected image: \(error)")
                }
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
                            AvatarImage(image: personaImage, size: Layout.avatarSize)
                        }
                        .padding(.trailing, Layout.horizontalPadding)

                        VStack(alignment: .leading) {
                            Text("Name")
                                .foregroundColor(appTheme.primaryText.color)

                            TextField("Name", text: personaNameBinding)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.done)
                                .focused($focusedField, equals: .name)
                                .styledFormField()
                        }
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.vertical, Layout.verticalPadding)
                        .id(FocusedField.name)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.vertical, Layout.verticalPadding)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .foregroundColor(appTheme.primaryText.color)

                        EnhancedTextEditor(
                            text: personaDescriptionBinding,
                            placeholder: "Describe how this persona should represent you...",
                            maxHeight: Layout.editorHeight,
                            minHeight: Layout.editorHeight,
                            textColor: UIColor(appTheme.primaryText.color),
                            placeholderColor: UIColor(appTheme.secondaryText.color)
                        )
                        .focused($focusedField, equals: .description)
                        .frame(height: Layout.editorHeight)
                        .foregroundStyle(appTheme.primaryText.color)
                        .background(appTheme.secondaryBackgroundColor.color)
                        .clipShape(
                            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.vertical, Layout.verticalPadding)
                    .id(FocusedField.description)
                }
                .padding(.bottom, 24)
            }
            .onChange(of: focusedField) { _, field in
                scrollFocusedFieldIntoView(field, proxy: proxy)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
    }

    private var personaNameBinding: Binding<String> {
        Binding {
            editablePersona?.name ?? ""
        } set: { value in
            editablePersona?.name = value
        }
    }

    private var personaDescriptionBinding: Binding<String> {
        Binding {
            editablePersona?.description ?? ""
        } set: { value in
            editablePersona?.description = value
        }
    }

    private var personaImage: Image? {
        guard let imageData = editablePersona?.imageData,
            let uiImage = UIImage(data: imageData)
        else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    private func syncPersonaFromStore() {
        guard editablePersona == nil, let active = personaStore.activePersona else {
            return
        }

        editablePersona = active
        isNewPersona = false
    }

    private func savePersona() {
        guard var persona = editablePersona else {
            return
        }

        persona.active = true
        personaStore.savePersona(persona)
        editablePersona = persona
        focusedField = nil
        isNewPersona = false
        dismiss()
    }

    private func scrollFocusedFieldIntoView(_ field: FocusedField?, proxy: ScrollViewProxy) {
        guard let field else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
    }
}
