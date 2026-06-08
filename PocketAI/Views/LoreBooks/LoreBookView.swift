import SwiftUI
import UIKit

struct LoreBookView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.appTheme) private var appTheme
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = LoreBookViewModel()

    private let loreBookID: UUID?
    private let importedLoreBook: LoreBookModel?
    private let onSave: ((LoreBookModel) -> Void)?

    init(
        loreBookID: UUID? = nil,
        importedLoreBook: LoreBookModel? = nil,
        onSave: ((LoreBookModel) -> Void)? = nil
    ) {
        self.loreBookID = loreBookID
        self.importedLoreBook = importedLoreBook
        self.onSave = onSave
    }

    var body: some View {
        Group {
            if viewModel.shouldHidePrivateContent {
                ContentUnavailableView(
                    "Private Lorebook Locked",
                    systemImage: "lock.fill",
                    description: Text("Unlock the app in Settings to view this lorebook.")
                )
            } else {
                settingsContent
            }
        }
        .task(id: loreBookID ?? importedLoreBook?.id) {
            if let importedLoreBook {
                viewModel.loadImportedLoreBook(importedLoreBook)
            } else {
                viewModel.loadLoreBook(withID: loreBookID)
            }
        }
    }

    private var settingsContent: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                loreBookSection
                scanningSection
                entriesSection
            }
            .padding(.vertical, 24)
        }
        .navigationTitle(viewModel.loreBook.name.isEmpty ? "New Lorebook" : viewModel.loreBook.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(appTheme.backgroundColor.color)
        .scrollDismissesKeyboard(.immediately)
        .sheet(item: viewModel.selectedEntryBinding) { entry in
            if let entryBinding = viewModel.entryBinding(for: entry.id) {
                LoreBookEntryDetailView(
                    entry: entryBinding,
                    onDelete: {
                        viewModel.deleteEntry(entry.id)
                        viewModel.selectedEntryID = nil
                    }
                )
                .presentationBackground(appTheme.backgroundColor.color)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let onSave {
                        onSave(viewModel.loreBook)
                        dismiss()
                    } else {
                        Task {
                            await saveLoreBook()
                        }
                    }
                }
            }
        }
        .alert("Lorebook Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }

    private var loreBookSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: 16) {
            LoreBookSectionHeader(
                title: "Lorebook",
                subtitle: "Name this lorebook and describe the context it should provide."
            )

            LoreBookTextField(
                title: "Name",
                placeholder: "World Lore",
                text: $viewModel.loreBook.name,
                autocapitalization: .words
            )

            LoreBookTextEditor(
                title: "Description",
                placeholder: "What this lorebook is for...",
                text: Binding(
                    get: { viewModel.loreBook.description ?? "" },
                    set: { viewModel.loreBook.description = $0 }
                ),
                height: 120
            )

            AppSheetOptionCard {
                Toggle(isOn: $viewModel.setPrivate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Lorebook")
                            .foregroundColor(appTheme.primaryText.color)

                        Text("Hide this lorebook while the app is locked.")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                }
                .tint(appTheme.tintColor.color)
            }
        }
        .padding(.horizontal, 16)
    }

    private var scanningSection: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: 16) {
            LoreBookSectionHeader(
                title: "Scanning",
                subtitle: "Tune how this lorebook is scanned while preparing model context."
            )

            AppSheetOptionCard {
                Stepper(value: $viewModel.loreBook.scanDepth, in: 0...50) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Depth")
                            .foregroundStyle(appTheme.primaryText.color)

                        Text("\(viewModel.loreBook.scanDepth)")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                }
                .tint(appTheme.tintColor.color)
            }

            LoreBookTextField(
                title: "Token Budget",
                placeholder: "Optional",
                text: $viewModel.tokenBudgetText,
                keyboardType: .numberPad,
                autocapitalization: .never
            )

            AppSheetOptionCard {
                Toggle(isOn: $viewModel.loreBook.recursiveScanning) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recursive Scanning")
                            .foregroundColor(appTheme.primaryText.color)

                        Text("Allow matched entries to trigger additional entry scans.")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                }
                .tint(appTheme.tintColor.color)
            }
        }
        .padding(.horizontal, 16)
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                LoreBookSectionHeader(
                    title: "Entries",
                    subtitle: "\(viewModel.loreBook.entries.count) total"
                )

                Spacer()

                Button {
                    viewModel.addEntry()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(appTheme.tintColor.color)
                        .font(.title2)
                }
            }
            .padding(.horizontal, 16)

            entrySearchField

            if viewModel.filteredEntries.isEmpty {
                ContentUnavailableView(
                    viewModel.entrySearchText.isEmpty ? "No Entries" : "No Matching Entries",
                    systemImage: "text.book.closed",
                    description: Text(
                        viewModel.entrySearchText.isEmpty
                            ? "Add entries to define reusable lore, facts, and context triggers."
                            : "Try a different key or content search.")
                )
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredEntries) { entry in
                        LoreBookEntryRow(
                            entry: entry,
                            isEnabled: viewModel.entryEnabledBinding(for: entry.id),
                            onSelect: {
                                viewModel.selectedEntryID = entry.id
                            }
                        )
                        .withBottomContextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteEntry(entry.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var entrySearchField: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(appTheme.secondaryText.color)

            TextField(
                "",
                text: $viewModel.entrySearchText,
                prompt: Text("Search entries").foregroundStyle(appTheme.secondaryText.color)
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .foregroundStyle(appTheme.primaryText.color)

            if !viewModel.entrySearchText.isEmpty {
                Button {
                    viewModel.entrySearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(appTheme.secondaryText.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        }
    }

    private func saveLoreBook() async {
        do {
            try await viewModel.saveLoreBook()
            UIApplication.shared.endEditing()
            navManager.popBack()
        } catch {
            viewModel.errorMessage = "Failed to save lorebook."
            print("Failed to save lorebook: \(error)")
        }
    }
}
