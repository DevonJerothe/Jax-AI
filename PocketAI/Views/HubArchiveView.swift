import SwiftUI 

public struct HubArchiveView: View {
    @State private var charHubViewModel: CharHubViewModel = .init()

    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                TextField("Search characters...", text: $charHubViewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                    .onSubmit {
                        Task { await charHubViewModel.searchCharacters(query: charHubViewModel.searchQuery, page: 1, count: charHubViewModel.searchCount) }
                    }
                
                Button("Search") {
                    Task { await charHubViewModel.searchCharacters(query: charHubViewModel.searchQuery, page: 1, count: charHubViewModel.searchCount) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.secondary)
                .foregroundStyle(.primary)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Results grid with infinite scroll
            if charHubViewModel.searchResults.isEmpty == false {
                CharHubResultsGrid(
                    viewModel: charHubViewModel,
                    loadMore: {
                        await charHubViewModel.loadNextPageIfPossible()
                    }
                )
            } else if charHubViewModel.isLoading {
                Spacer() 
                LoadingIndicator(size: 30)
                Spacer() 
            } else if charHubViewModel.searchQuery.isEmpty == false {
                Spacer()
                Text("No Results Found...")
                Spacer()
            } else {
                Spacer()
                Text("Search The Hub!")
                Spacer() 
            }
        }
    }
}

struct CharHubResultsGrid: View {
    @Environment(NavigationManager.self) var navManager
    @Bindable var viewModel: CharHubViewModel
    let loadMore: () async -> Void
    @State private var lastTriggerIndex: Int = -1
    @State private var allowTrigger: Bool = true
    @State private var hasScrolledDown: Bool = false

    private let columns: [GridItem] = [
        GridItem(.flexible(maximum: 200), spacing: 16),
        GridItem(.flexible(maximum: 200), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { index, item in
                    CharHubCardPreview(card: item)
                        .onTapGesture {
                            Task {
                                let _ = await viewModel.getCharacter(card: item)
                            }
                        }
                }
                
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                            let screenHeight = UIScreen.main.bounds.height
                            if newValue < screenHeight {
                                Task {
                                    await loadMore()
                                }
                            }
                        }
                }

                // Loading/empty states
                if viewModel.isLoading && viewModel.searchPage > 1 {
                    HStack { Spacer() ; LoadingIndicator(size: 30) ; Spacer() }
                        .padding(.vertical, 12)
                        .gridCellColumns(2)
                }
            }
            .padding()
        }
    }
}

struct CharHubCardPreview: View {
    let card: CharHubModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thubmnailURL = card.thumbnail {
                AsyncImage(url: thubmnailURL) { state in
                    switch state {
                    case .empty:
                        HStack {
                            Spacer()
                            LoadingIndicator(size: 30)
                                .frame(height: 150)
                            Spacer()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .frame(maxWidth: 195)
                            .clipped()
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                            )
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(card.tagline ?? card.description ?? "No description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                Spacer()
                
                HStack {
                    Text(card.source ?? "unknown")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(card.tags?.prefix(3).joined(separator: ", ") ?? "No tags")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}