import SwiftUI

public struct BooruBrowserView: View {
    @State private var viewModel: BotBooruViewModel = .init()
    @State private var showSettings = false

    public var body: some View {
        VStack {
            if viewModel.loggedIn == false {
                Spacer()
                ContentUnavailableView {
                    Label("Log in to BotBooru", systemImage: "person.crop.circle.badge.questionmark")
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
                    BooruBrowserResultsView(viewModel: viewModel)
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
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            BooruBrowserSettingsView(viewModel: viewModel)
        }
        .safeAreaInset(edge: .top, spacing: 6) {
            if viewModel.loggedIn {
                HStack {
                    TextField("Search the booru..", text: $viewModel.searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.systemGray6).opacity(0.6))
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
                            .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
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

private struct BooruBrowserSettingsView: View {
    @Bindable var viewModel: BotBooruViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard {
                    HStack {
                        Label(
                            viewModel.loggedIn ? "Logged In" : "Logged Out",
                            systemImage: viewModel.loggedIn ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        Spacer()
                        Text(viewModel.authSettings.username ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.loggedIn == false {
                    settingsCard("Login") {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        SecureField("Password", text: $password)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        Button {
                            Task { await viewModel.login(username: username, password: password) }
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Login")
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .disabled(username.isEmpty || password.isEmpty || viewModel.isLoading)
                    }
                }

                settingsCard("Browsing") {
                    Toggle("Show NSFW", isOn: authBinding(\.showNSFW))
                    Toggle("Hide AI", isOn: authBinding(\.hideAI))
                }
                .disabled(viewModel.loggedIn == false)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Booru Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            username = viewModel.authSettings.username ?? ""
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

    private func authBinding(_ keyPath: WritableKeyPath<BotBooruAuthSettings, Bool>) -> Binding<Bool> {
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
                            await viewModel.getCharacter(post: post)
                        }
                    }
            }
        )
    }
}

struct BooruBrowserPostCard: View {
    let post: BotBooruPostItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: post.thumbnail) { state in
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

            VStack(alignment: .leading, spacing: 4) {
                Text(post.characterName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer() 
                HStack {
                    Text(post.tags.map { $0.name }.prefix(3).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .truncationMode(.tail)
                    
                    Spacer()

                    Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
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
}
