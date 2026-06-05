import SwiftUI
import UniformTypeIdentifiers

public struct CharImportView: View {
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: CharImportViewModel = .init()
    @State private var showingFileImporter = false
    @State private var showCharacterEditor = false
    @FocusState private var isURLFieldFocused: Bool

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                fileImportSection
                remoteImportSection

                if viewModel.isImporting {
                    loadingSection
                }

                if let error = viewModel.importError {
                    errorSection(error)
                }

                if let characterCard = viewModel.characterCard {
                    importedCardPreview(characterCard)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Import Character")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .navigationDestination(isPresented: $showCharacterEditor) {
            if let characterCard = viewModel.characterCard {
                CharacterCardSettingsView(
                    characterCard: characterCard,
                    isNew: true,
                    dismissOnSave: true,
                    navigateToCharacterListOnSave: true
                )
            }
        }
    }

    private var supportedContentTypes: [UTType] {
        [
            .json,
            .png,
            UTType(filenameExtension: "card") ?? .data,
            .data
        ]
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import Character Card")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(appTheme.primaryText.color)

            Text("Choose a local PNG or JSON card, or paste a remote card URL.")
                .font(.subheadline)
                .foregroundStyle(appTheme.secondaryText.color)
        }
        .padding(.horizontal, 16)
    }

    private var fileImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local File")
                .foregroundColor(appTheme.primaryText.color)

            Button {
                isURLFieldFocused = false
                showingFileImporter = true
            } label: {
                HStack {
                    Label("Choose File", systemImage: "doc.badge.plus")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appTheme.secondaryText.color)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(appTheme.secondaryBackgroundColor.color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isImporting)
        }
        .padding(.horizontal, 16)
    }

    private var remoteImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote URL")
                .foregroundColor(appTheme.primaryText.color)

            HStack(spacing: 10) {
                TextField("https://example.com/character.png", text: $viewModel.urlEntry)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .focused($isURLFieldFocused)
                    .styledFormField()
                    .onSubmit {
                        importRemoteCard()
                    }

                Button {
                    importRemoteCard()
                } label: {
                    if viewModel.isImporting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(appTheme.primaryText.color)
                    } else {
                        Image(systemName: "arrow.down.doc")
                            .font(.headline)
                    }
                }
                .frame(width: 48, height: 48)
                .foregroundStyle(appTheme.primaryText.color)
                .background(appTheme.primaryAction.color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(viewModel.canImportRemoteCard == false)
            }
        }
        .padding(.horizontal, 16)
    }

    private var loadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(appTheme.tintColor.color)

            Text("Importing character card...")
                .font(.subheadline)
                .foregroundStyle(appTheme.secondaryText.color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func errorSection(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(appTheme.destructiveAction.color)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(appTheme.destructiveAction.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func importedCardPreview(_ characterCard: CharacterCardModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarImage(image: characterCard.getAvatarImg(), size: 74)

                VStack(alignment: .leading, spacing: 4) {
                    Text(characterCard.name ?? "Unnamed Character")
                        .font(.headline)
                        .foregroundStyle(appTheme.primaryText.color)
                        .lineLimit(2)

                    Text(characterCard.cardTagline ?? characterCard.description ?? "Ready to review and save.")
                        .font(.subheadline)
                        .foregroundStyle(appTheme.secondaryText.color)
                        .lineLimit(3)
                }

                Spacer()
            }

            Button {
                showCharacterEditor = true
            } label: {
                HStack {
                    Spacer()
                    Label("Review and Save", systemImage: "square.and.pencil")
                    Spacer()
                }
                .padding(.vertical, 11)
            }
            .foregroundStyle(appTheme.primaryText.color)
            .background(appTheme.primaryAction.color)
            .clipShape(Capsule())
        }
        .padding()
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func importRemoteCard() {
        isURLFieldFocused = false
        Task {
            await viewModel.importRemoteCard()
            showCharacterEditor = viewModel.characterCard != nil
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importLocalCard(from: url)
                showCharacterEditor = viewModel.characterCard != nil
            }
        case .failure(let error):
            viewModel.importError = error.localizedDescription
        }
    }
}
