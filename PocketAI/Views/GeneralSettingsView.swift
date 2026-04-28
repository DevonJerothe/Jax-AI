import SwiftUI

struct GeneralSettingsView: View {
    @State private var booruViewModel: BotBooruViewModel = .init(loadPosts: false)
    @State private var chubViewModel: ChubAIViewModel = .init(loadCards: false)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard("Core") {
                    NavigationLink {
                        ConnectionSettingsView()
                    } label: {
                        SettingsNavigationRow(
                            title: "Connection",
                            subtitle: "Provider, model, context, and response length",
                            systemImage: "network"
                        )
                    }
                    .buttonStyle(.plain)
                }

                SettingsCard("Browsers") {
                    NavigationLink {
                        BooruBrowserSettingsView(viewModel: booruViewModel)
                    } label: {
                        SettingsNavigationRow(
                            title: "BotBooru",
                            subtitle: "Account login and browsing filters",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {
                        ChubAISettingsView(viewModel: chubViewModel)
                    } label: {
                        SettingsNavigationRow(
                            title: "Chub AI",
                            subtitle: "Content filters and excluded topics",
                            systemImage: "person.2.crop.square.stack"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
