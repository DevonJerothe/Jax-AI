import SwiftUI
import UniformTypeIdentifiers

public struct CharImportView: View {
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: CharImportViewModel
    @State private var showingFileImporter = false
    @State private var showImportedContentEditor = false
    @FocusState private var isURLFieldFocused: Bool

    private let importType: CharImportType

    public init(importType: CharImportType = .characterCard) {
        self.importType = importType
        self._viewModel = State(initialValue: CharImportViewModel(importType: importType))
    }

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

                switch importType {
                case .characterCard:
                    if let characterCard = viewModel.characterCard {
                        importedCardPreview(characterCard)
                    }
                case .loreBook:
                    if let loreBook = viewModel.loreBook {
                        importedLoreBookPreview(loreBook)
                    }
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(appTheme.backgroundColor.color)
        .navigationTitle(navigationTitle)
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
        .navigationDestination(isPresented: $showImportedContentEditor) {
            switch importType {
            case .characterCard:
                if let characterCard = viewModel.characterCard {
                    CharacterCardSettingsView(
                        characterCard: characterCard,
                        isNew: true,
                        dismissOnSave: true,
                        navigateToCharacterListOnSave: true
                    )
                }
            case .loreBook:
                if let loreBook = viewModel.loreBook {
                    LoreBookView(importedLoreBook: loreBook)
                }
            }
        }
    }

    private var supportedContentTypes: [UTType] {
        switch importType {
        case .characterCard:
            return [
                .json,
                .png,
                UTType(filenameExtension: "card") ?? .data,
                .data,
            ]
        case .loreBook:
            return [.json]
        }
    }

    private var navigationTitle: String {
        switch importType {
        case .characterCard:
            return "Import Character"
        case .loreBook:
            return "Import Lorebook"
        }
    }

    private var headerTitle: String {
        switch importType {
        case .characterCard:
            return "Import Character Card"
        case .loreBook:
            return "Import Lorebook"
        }
    }

    private var headerDescription: String {
        switch importType {
        case .characterCard:
            return "Choose a local PNG or JSON card, or paste a remote card URL."
        case .loreBook:
            return "Choose a local JSON lorebook, or paste a remote lorebook URL."
        }
    }

    private var urlPlaceholder: String {
        switch importType {
        case .characterCard:
            return "https://example.com/character.png"
        case .loreBook:
            return "https://example.com/lorebook.json"
        }
    }

    private var loadingMessage: String {
        switch importType {
        case .characterCard:
            return "Importing character card..."
        case .loreBook:
            return "Importing lorebook..."
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(appTheme.primaryText.color)

            Text(headerDescription)
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
                TextField(urlPlaceholder, text: $viewModel.urlEntry)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .focused($isURLFieldFocused)
                    .styledFormField()
                    .onSubmit {
                        importRemoteContent()
                    }

                Button {
                    importRemoteContent()
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
                .disabled(viewModel.canImportRemoteContent == false)
            }
        }
        .padding(.horizontal, 16)
    }

    private var loadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(appTheme.tintColor.color)

            Text(loadingMessage)
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
        importedContentPreview(
            title: characterCard.name ?? "Unnamed Character",
            subtitle: characterCard.cardTagline ?? characterCard.description
                ?? "Ready to review and save."
        ) {
            AvatarImage(image: characterCard.getAvatarImg(), size: 74)
        }
    }

    private func importedLoreBookPreview(_ loreBook: LoreBookModel) -> some View {
        importedContentPreview(
            title: loreBook.name,
            subtitle: loreBook.description
                ?? "\(loreBook.entries.count) entries ready to review and save."
        ) {
            Image(systemName: "book.closed")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(appTheme.tintColor.color)
                .frame(width: 74, height: 74)
                .background(appTheme.backgroundColor.color)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func importedContentPreview<Leading: View>(
        title: String,
        subtitle: String,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                leading()

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(appTheme.primaryText.color)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(appTheme.secondaryText.color)
                        .lineLimit(3)
                }

                Spacer()
            }

            Button {
                showImportedContentEditor = true
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

    private func importRemoteContent() {
        isURLFieldFocused = false
        Task {
            await viewModel.importRemoteContent()
            showImportedContentEditor = viewModel.characterCard != nil || viewModel.loreBook != nil
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importLocalContent(from: url)
                showImportedContentEditor =
                    viewModel.characterCard != nil || viewModel.loreBook != nil
            }
        case .failure(let error):
            viewModel.importError = error.localizedDescription
            viewModel.characterCard = nil
            viewModel.loreBook = nil
        }
    }
}
