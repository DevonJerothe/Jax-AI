import SwiftUI 
import SwiftLLMSDK

public struct ChubAIBrowserView: View {
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: ChubAIViewModel = .init()
    @State private var showSettings = false
    @State private var showTopicSearch = false
    @State private var selectedCharacterCard: CharacterCardModel?
    @State private var showCharacterEditor = false

    public var body: some View {
        VStack {
            if viewModel.loggedIn == false {
                Spacer() 
                ContentUnavailableView {
                    Label("Log in to Chub AI", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Open settings to connect your Chub AI account")
                } actions: {
                    Button("Settings") {
                        showSettings = true
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
                Spacer()
            } else {
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
                                        if let characterCard = await viewModel.getCharacter(card: card) {
                                            selectedCharacterCard = characterCard
                                            showCharacterEditor = true
                                        }
                                    }
                                }
                        }
                    )
                    .padding(.horizontal, 16)
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
                    .foregroundColor(appTheme.primaryText.color)
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            ChubAISettingsView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showTopicSearch) {
            ChubAITopicSearchView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showCharacterEditor) {
            if let selectedCharacterCard {
                CharacterCardSettingsView(
                    characterCard: selectedCharacterCard,
                    isNew: true,
                    dismissOnSave: true
                )
            }
        }
        .task {
            await viewModel.getTags()
        }
        .onChange(of: showSettings) { old, new in 
            guard old == true, new == false else { return }
            Task { await viewModel.searchCards(refresh: true) }
        }
        .safeAreaInset(edge: .top, spacing: 6) {
            if viewModel.loggedIn {
                HStack {
                    TextField("Search the hub..", text: $viewModel.searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .foregroundStyle(appTheme.primaryText.color)
                        .background(appTheme.secondaryBackgroundColor.color)
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
                            .foregroundColor(appTheme.secondaryText.color)
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
                            .foregroundColor(appTheme.secondaryText.color)
                            .glassCapsule()
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 19)
                }
            }
        }
        .background(appTheme.backgroundColor.color)
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
    @Environment(\.appTheme) private var appTheme

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
                            .fill(appTheme.secondaryAction.color)
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(appTheme.secondaryText.color)
                            )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "")
                    .font(.headline)
                    .foregroundColor(appTheme.primaryText.color)

                Text(card.tagline ?? card.description ?? "No description available.")
                    .font(.caption)
                    .foregroundColor(appTheme.secondaryText.color)
                    .lineLimit(3)

                Spacer() 

                HStack {
                    Text(card.topics?.prefix(3).joined(separator: ", ") ?? "")
                        .font(.caption2)
                        .foregroundColor(appTheme.secondaryText.color)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer() 

                    Text(getFormattedTimestamp(stringDate: card.createdAt ?? ""))
                        .font(.caption2)
                        .foregroundColor(appTheme.secondaryText.color)
                        .lineLimit(3)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(appTheme.secondaryBackgroundColor.color)
        .cornerRadius(12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }


    private func getFormattedTimestamp(stringDate: String) -> String {
        // Format the timestamp of the last message
        guard let date = ISO8601DateFormatter().date(from: stringDate) else {
            return ""
        }

        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day, daysAgo > 7 {
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct ChubAITopicSearchView: View {
    @Bindable var viewModel: ChubAIViewModel
    @Environment(\.appTheme) private var appTheme
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
                    .foregroundStyle(appTheme.primaryText.color)
            }
        }
        .scrollContentBackground(.hidden)
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Add Topic")
        .searchable(text: $search, prompt: "Search topics")
    }
}

struct ChubAISettingsView: View {
    @Environment(\.appTheme) private var appTheme

    @Bindable var viewModel: ChubAIViewModel
    @State private var tagSearch = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        let filteredTags = viewModel.tags
            .filter { tagSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(tagSearch) || $0.title.localizedCaseInsensitiveContains(tagSearch) }
            .filter { tag in !viewModel.excludedTopics.contains { $0.id == tag.id } }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard {
                    HStack {
                        Label(
                            viewModel.loggedIn ? "Logged In" : "Logged Out", 
                            systemImage: viewModel.loggedIn ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        Spacer() 
                        Text(viewModel.chubSettings.userName ?? "")
                            .font(.caption)
                            .foregroundColor(appTheme.secondaryText.color)
                    }
                    if viewModel.loggedIn {
                        Button {
                            viewModel.logout()
                        } label: {
                            HStack {
                                Spacer() 
                                Text("Logout")
                                    .foregroundStyle(appTheme.primaryText.color)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .buttonStyle(.plain)
                        .background(appTheme.destructiveAction.color.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                if viewModel.loggedIn == false {
                    SettingsCard("Login") {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .styledFormField()

                        SecureField("Password", text: $password)
                            .styledFormField()

                        if !viewModel.loginError.isEmpty {
                            Text(viewModel.loginError)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }

                        Button {
                            Task { await viewModel.login(username: username, password: password) }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Login")
                                        .foregroundStyle(appTheme.primaryText.color)
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .background(appTheme.primaryAction.color.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
                        .disabled(username.isEmpty || password.isEmpty || viewModel.isLoading)
                    }
                }
                
                SettingsCard("Excluded Topics") {
                    TextField("Search tags", text: $tagSearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .styledFormField()

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
                                    .foregroundColor(appTheme.secondaryText.color)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(appTheme.secondaryAction.color)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Chub AI Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.getTags()
        }
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
