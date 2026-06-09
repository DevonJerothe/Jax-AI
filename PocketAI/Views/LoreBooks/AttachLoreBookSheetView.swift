import SwiftUI

struct AttachLoreBookSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var appTheme

    @Bindable var viewModel: LoreBookViewModel
    @State private var searchText = ""
    @State private var selectedLoreBookIDs: Set<UUID> = []
    @State private var isSaving = false

    private var filteredLoreBooks: [LoreBookModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return viewModel.attachableLoreBooks
        }

        return viewModel.attachableLoreBooks.filter { loreBook in
            loreBook.name.localizedCaseInsensitiveContains(query)
                || (loreBook.description?.localizedCaseInsensitiveContains(query) ?? false)
                || loreBook.entries.contains { entry in
                    entry.name.localizedCaseInsensitiveContains(query)
                        || entry.keys.contains { $0.localizedCaseInsensitiveContains(query) }
                        || entry.content.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var newSelectionIDs: Set<UUID> {
        selectedLoreBookIDs.subtracting(viewModel.attachedLoreBookIDs)
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredLoreBooks.isEmpty {
                    ContentUnavailableView {
                        Label(
                            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No Lorebooks Available"
                                : "No Results",
                            systemImage: "book.closed")
                    } description: {
                        Text(
                            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Create or unlock a lorebook before attaching it to this chat."
                                : "Try a different name, key, or entry search.")
                    }
                } else {
                    List(filteredLoreBooks) { loreBook in
                        loreBookRow(loreBook)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(appTheme.backgroundColor.color)
            .navigationTitle("Attach Lorebook")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search lorebooks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await saveSelection()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(newSelectionIDs.isEmpty || isSaving)
                }
            }
            .onAppear {
                selectedLoreBookIDs = viewModel.attachedLoreBookIDs
            }
        }
    }

    private func loreBookRow(_ loreBook: LoreBookModel) -> some View {
        let isAttached = viewModel.attachedLoreBookIDs.contains(loreBook.id)
        let isSelected = selectedLoreBookIDs.contains(loreBook.id)

        return Button {
            guard !isAttached else {
                return
            }

            if isSelected {
                selectedLoreBookIDs.remove(loreBook.id)
            } else {
                selectedLoreBookIDs.insert(loreBook.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: loreBook.isPrivate ? "book.closed.fill" : "book.closed")
                    .font(.title3)
                    .foregroundStyle(appTheme.tintColor.color)
                    .frame(width: 34, height: 34)
                    .background(appTheme.secondaryAction.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(loreBook.name)
                            .font(.headline)
                            .foregroundStyle(appTheme.primaryText.color)
                            .lineLimit(1)

                        if loreBook.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }

                    Text(
                        loreBook.description?.isEmpty == false
                            ? loreBook.description! : "No description available."
                    )
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
                    .lineLimit(2)

                    HStack(spacing: 12) {
                        Label("\(loreBook.entries.count) entries", systemImage: "text.book.closed")
                        Text("Depth \(loreBook.scanDepth)")

                        if isAttached {
                            Label("Attached", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(appTheme.tintColor.color)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(appTheme.secondaryText.color)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        isSelected ? appTheme.tintColor.color : appTheme.secondaryText.color)
            }
            .padding(14)
            .background(appTheme.secondaryBackgroundColor.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isAttached ? 0.75 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isAttached)
    }

    private func saveSelection() async {
        isSaving = true
        await viewModel.attachLoreBooks(withIDs: newSelectionIDs)
        isSaving = false
        dismiss()
    }
}
