import SwiftUI

public struct BooruBrowserView: View {
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: BotBooruViewModel = .init()
    @State private var showSettings = false
    @State private var selectedCharacterCard: CharacterCardModel?
    @State private var showCharacterEditor = false

    public var body: some View {
        VStack {
            if viewModel.loggedIn == false {
                Spacer()
                ContentUnavailableView {
                    Label(
                        "Log in to BotBooru", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Open settings to connect your BotBooru account.")
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
                if viewModel.posts.isEmpty == false {
                    BooruBrowserResultsView(viewModel: viewModel) { characterCard in
                        selectedCharacterCard = characterCard
                        showCharacterEditor = true
                    }
                } else if viewModel.isLoading {
                    Spacer()
                    LoadingIndicator(size: 30)
                    Spacer()
                } else {
                    Spacer()
                    Text("No posts found...")
                    Spacer()
                }
            }
        }
        .navigationBarTitle("Booru Browser")
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
            BooruBrowserSettingsView(viewModel: viewModel)
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
        .safeAreaInset(edge: .top, spacing: 6) {
            if viewModel.loggedIn {
                HStack {
                    TextField("Search the booru..", text: $viewModel.searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .foregroundStyle(appTheme.primaryText.color)
                        .background(appTheme.secondaryBackgroundColor.color)
                        .cornerRadius(12)
                        .onSubmit {
                            Task { await viewModel.getPosts(refresh: true) }
                        }
                        .glassEffect(
                            .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .padding(.leading, 14)
                        .padding(.trailing, 8)

                    Menu {
                        Picker("Sort", selection: sortSelection) {
                            ForEach(BotBooruSort.allCases) { sort in
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
                    .padding(.trailing, showsSortTimeMenu ? 4 : 19)

                    if showsSortTimeMenu {
                        Menu {
                            Picker("Time", selection: sortTimeSelection) {
                                ForEach(BotBooruSortTime.allCases) { sortTime in
                                    Text(sortTime.title)
                                        .tag(sortTime)
                                }
                            }
                        } label: {
                            Image(systemName: "clock.fill")
                                .foregroundColor(appTheme.secondaryText.color)
                                .glassCapsule()
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 19)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                    }
                }
                // .animation(.snappy(duration: 0.22), value: showsSortTimeMenu)
            }
        }
        .background(appTheme.backgroundColor.color)
        .task {
            await viewModel.loadInitialPosts()
        }
    }

    private var showsSortTimeMenu: Bool {
        viewModel.sort != .latest
    }

    private var sortSelection: Binding<BotBooruSort> {
        Binding {
            viewModel.sort
        } set: { sort in
            guard viewModel.sort != sort else { return }
            withAnimation(.snappy(duration: 0.22)) {
                viewModel.sort = sort
            }
            Task { await viewModel.getPosts(refresh: true) }
        }
    }

    private var sortTimeSelection: Binding<BotBooruSortTime> {
        Binding {
            viewModel.sortTime
        } set: { sortTime in
            guard viewModel.sortTime != sortTime else { return }
            viewModel.sortTime = sortTime
            Task { await viewModel.getPosts(refresh: true) }
        }
    }
}

struct BooruBrowserSettingsView: View {
    @Environment(\.appTheme) private var appTheme

    @Bindable var viewModel: BotBooruViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard {
                    HStack {
                        Label(
                            viewModel.loggedIn ? "Logged In" : "Logged Out",
                            systemImage: viewModel.loggedIn
                                ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        Spacer()
                        Text(viewModel.authSettings.username ?? "")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                    if viewModel.loggedIn {
                        HStack(spacing: 12) {
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
                            .glassEffect(
                                .regular.interactive(), in: RoundedRectangle(cornerRadius: 16))

                            Button {
                                Task { await viewModel.refreshLogin() }
                            } label: {
                                HStack {
                                    Spacer()
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(appTheme.primaryText.color)
                                    } else {
                                        Text("Refresh Login")
                                            .foregroundStyle(appTheme.primaryText.color)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 10)
                            .buttonStyle(.plain)
                            .background(appTheme.primaryAction.color.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .glassEffect(
                                .regular.interactive(), in: RoundedRectangle(cornerRadius: 16)
                            )
                            .disabled(viewModel.isLoading)
                        }
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

                SettingsCard("Browsing") {
                    Toggle("Hide AI Assisted Content", isOn: authBinding(\.hideAI))
                }
                .tint(appTheme.tintColor.color)
                .disabled(viewModel.loggedIn == false)
            }
            .padding(16)
        }
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Booru Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            username = viewModel.authSettings.username ?? ""
        }
    }

    private func authBinding(_ keyPath: WritableKeyPath<BotBooruAuthSettings, Bool>) -> Binding<
        Bool
    > {
        Binding {
            viewModel.authSettings[keyPath: keyPath]
        } set: { value in
            var settings = viewModel.authSettings
            settings[keyPath: keyPath] = value
            viewModel.updateAuthSettings(settings)
        }
    }
}

struct BooruBrowserResultsView: View {
    @Bindable var viewModel: BotBooruViewModel
    let onSelectCharacter: (CharacterCardModel) -> Void

    var body: some View {
        PaginatedResultsGridView(
            items: viewModel.posts,
            isLoading: viewModel.isLoading,
            canLoadMore: viewModel.posts.count < viewModel.count,
            loadMore: {
                await viewModel.loadMore()
            },
            cardBuilder: { post in
                BooruBrowserPostCard(post: post)
                    .onTapGesture {
                        Task {
                            if let characterCard = await viewModel.getCharacter(post: post) {
                                onSelectCharacter(characterCard)
                            }
                        }
                    }
            }
        )
        .padding(.horizontal, 16)
    }
}

struct BooruBrowserPostCard: View {
    let post: BotBooruPostItem

    var body: some View {
        ThumbnailInfoCard(
            imageURL: post.thumbnail,
            title: post.characterName,
            subtitle: post.creatorNote ?? "",
            leadingMetadata: post.tags.map { $0.name ?? "" }.prefix(3).joined(separator: ", "),
            trailingMetadata: AppDateFormatting.thumbnailTimestamp(from: post.createdAt)
        )
    }
}
