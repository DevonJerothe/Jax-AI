import SwiftUI 
import SwiftLLMSDK

public struct ChubAIBrowserView: View {
    @State private var viewModel: ChubAIViewModel = .init()
    @State private var showSettings = false
    @State private var showTopicSearch = false

    public var body: some View {
        VStack {
            if viewModel.cards.isEmpty == false {
                PaginatedResultsGridView(
                    items: viewModel.cards, 
                    isLoading: viewModel.isLoading, 
                    canLoadMore: viewModel.hasMore, 
                    loadMore: {
                        await viewModel.loadMore()
                    }, 
                    cardBuilder: { card in 
                        ChubBrowserCard(card: card)
                            .onTapGesture {
                                Task { 
                                    await viewModel.getCharacter(card: card)
                                }
                            }
                    }
                ) 
            } else if viewModel.isLoading {
                Spacer()
                LoadingIndicator(size: 30)
                Spacer()
            } else {
                Spacer()
                Text("No cards found...")
                Spacer()
            }
        }
        .navigationBarTitle("Chub AI Browser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            ChubAISettingsView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showTopicSearch) {
            ChubAITopicSearchView(viewModel: viewModel)
        }
        .onChange(of: showSettings) { old, new in 
            guard old == true, new == false else { return }
            Task { await viewModel.searchCards(refresh: true) }
        }
        .safeAreaInset(edge: .top, spacing: 6) {
            HStack {
                TextField("Search the hub..", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.6))
                    .cornerRadius(12)
                    .onSubmit {
                        Task { await viewModel.searchCards() }
                    }
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .padding(.leading, 14) 
                    .padding(.trailing, 8)

                Menu {
                    Picker("Sort", selection: sortSelection) { 
                        ForEach(ChubSort.allCases) { sort in 
                            Text(sort.title)
                                .tag(sort)
                        }
                    }

                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundColor(.secondary)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                // Tag selection menu 
                Menu {
                    ForEach(viewModel.selectedTopics) { tag in
                        Button {
                            viewModel.selectedTopics.removeAll { $0.id == tag.id }
                            Task { await viewModel.searchCards(refresh: true) }
                        } label: {
                            Label(tag.name, systemImage: "xmark.circle")
                        }
                    }

                    Button {
                        showTopicSearch = true
                    } label: {
                        Label("Add Topic", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.secondary)
                        .glassCapsule()
                }
                .buttonStyle(.plain)
                .padding(.trailing, 19)
            }
        }
    }

    private var sortSelection: Binding<ChubSort> {
        Binding {
            viewModel.sort
        }
        set: { sort in
            guard viewModel.sort != sort else { return }
            withAnimation(.snappy(duration: 0.22)) {
                viewModel.sort = sort
            }
            Task { await viewModel.searchCards(refresh: true) }
        }
    }
}

struct ChubBrowserCard: View {
    let card: ChubCardNode 

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: card.thumbnail) { state in 
                switch state {
                    case .empty: 
                        HStack {
                            Spacer() 
                            LoadingIndicator(size: 30)
                            Spacer() 
                        }
                        .frame(height: 150)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .frame(maxWidth: 195)
                            .clipped()
                    default: 
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

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(card.tagline ?? card.description ?? "No description available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Spacer() 

                HStack {
                    Text(card.topics?.prefix(3).joined(separator: ", ") ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer() 

                    Text(getFormattedTimestamp(stringDate: card.createdAt ?? ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }


    private func getFormattedTimestamp(stringDate: String) -> String {
        // Format the timestamp of the last message
        guard let date = ISO8601DateFormatter().date(from: stringDate) else {
            return ""
        }

        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
}

struct ChubAITopicSearchView: View {
    @Bindable var viewModel: ChubAIViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        let filteredTags = viewModel.tags
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.title.localizedCaseInsensitiveContains(search) }
            .filter { tag in !viewModel.selectedTopics.contains { $0.id == tag.id } }

        List(filteredTags.prefix(50)) { tag in
            Button {
                viewModel.selectedTopics.append(tag)
                Task { await viewModel.searchCards(refresh: true) }
                dismiss()
            } label: {
                Text(tag.title.isEmpty ? tag.name : tag.title)
            }
        }
        .navigationTitle("Add Topic")
        .searchable(text: $search, prompt: "Search topics")
    }
}

struct ChubAISettingsView: View {
    @Bindable var viewModel: ChubAIViewModel
    @State private var tagSearch = ""

    var body: some View {
        let filteredTags = viewModel.tags
            .filter { tagSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(tagSearch) || $0.title.localizedCaseInsensitiveContains(tagSearch) }
            .filter { tag in !viewModel.excludedTopics.contains { $0.id == tag.id } }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard {
                    Toggle("Show NSFW", isOn: chubBinding(\.showNSFW))
                    Toggle("Show NSFL", isOn: chubBinding(\.showNSFL))
                }
                settingsCard {
                    Text("Excluded Topics")

                    TextField("Search tags", text: $tagSearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    if tagSearch.isEmpty == false {
                        ForEach(filteredTags.prefix(20)) { tag in
                            Button {
                                viewModel.excludedTopics.append(tag)
                                var settings = viewModel.chubSettings
                                settings.excludedTopics = viewModel.excludedTopics
                                viewModel.updateChubSettings(settings)
                                tagSearch = ""
                            } label: {
                                Text(tag.title.isEmpty ? tag.name : tag.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(viewModel.excludedTopics) { tag in
                        HStack(spacing: 6) {
                            Text(tag.name)
                                .font(.caption)

                            Button {
                                viewModel.excludedTopics.removeAll { $0.id == tag.id }
                                var settings = viewModel.chubSettings
                                settings.excludedTopics = viewModel.excludedTopics
                                viewModel.updateChubSettings(settings)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
    }

        @ViewBuilder
    private func settingsCard<Content: View>(_ title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func chubBinding(_ keyPath: WritableKeyPath<ChubAISettings, Bool>) -> Binding<Bool> {
        Binding {
            viewModel.chubSettings[keyPath: keyPath]
        } set: { value in
            var settings = viewModel.chubSettings
            settings[keyPath: keyPath] = value
            viewModel.updateChubSettings(settings)
        }
    }
}
