import SwiftUI

struct LoreBookListView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.appTheme) private var appTheme
    @State private var viewModel = LoreBookViewModel()

    private let columns: [GridItem] = [
        GridItem(.flexible(maximum: 220), spacing: 16),
        GridItem(.flexible(maximum: 220), spacing: 16),
    ]

    var body: some View {
        @Bindable var viewModel = viewModel

        return ZStack {
            if viewModel.filteredLoreBooks.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.loreBookSearchText.isEmpty ? "No Lorebooks" : "No Results",
                        systemImage: "book.closed")
                } description: {
                    Text(
                        viewModel.loreBookSearchText.isEmpty
                            ? "Create a lorebook to organize reusable character and world context."
                            : "Try a different name, key, or entry search.")
                } actions: {
                    if viewModel.loreBookSearchText.isEmpty {
                        Button {
                            navManager.navigateToLoreBook(loreBookID: nil, keepCurrentPath: true)
                        } label: {
                            Label("Create Lorebook", systemImage: "plus")
                        }
                        .foregroundStyle(appTheme.tintColor.color)
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.filteredLoreBooks) { loreBook in
                            LoreBookPreview(loreBook: loreBook)
                                .onTapGesture {
                                    navManager.navigateToLoreBook(
                                        loreBookID: loreBook.id, keepCurrentPath: true)
                                }
                                .withBottomContextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteLoreBook(loreBook: loreBook)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Lorebooks")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.loreBookSearchText, prompt: "Search lorebooks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navManager.navigateToLoreBook(loreBookID: nil, keepCurrentPath: true)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .alert("Lorebook Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
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
}
