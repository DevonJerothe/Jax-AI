import SwiftUI

struct CharacterCardsView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.appTheme) private var appTheme
    @State var viewModel: CharacterCardsViewModel = CharacterCardsViewModel()
    var startChat: Bool

    init(startChat: Bool = false) {
        self.startChat = startChat
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(maximum: 200), spacing: 16),
        GridItem(.flexible(maximum: 200), spacing: 16),
    ]

    var body: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.characterCards, id: \.self) { card in
                        CharacterCardPreview(card: card)
                            .onTapGesture {
                                if startChat {
                                    Task {
                                        if let newChat = await viewModel.newChat(card: card) {
                                            navManager.navigateToChat(chatID: newChat.id)
                                        }
                                    }
                                } else {
                                    navManager.navigateToCharacter(
                                        characterID: card.id, keepCurrentPath: true)
                                }
                            }
                            .withBottomContextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteCharacterCard(card: card)
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
        .background(appTheme.backgroundColor.color)
        .scrollIndicators(.hidden)
        .navigationTitle("My Characters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    navManager.navigateToLoreBooks(keepCurrentPath: true)
                } label: {
                    Image(systemName: "book.closed")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Create From Scratch") {
                        navManager.navigateToNewChat(
                            keepCurrentPath: true, createCharacterCard: true)
                    }
                    Button("Import New Character") {
                        navManager.navigateToCharImport(keepCurrentPath: true)
                    }
                    if AppFeatures.characterBrowserEnabled {
                        Button("Browse ChubAI") {
                            navManager.navigateToChubAIBrowser(keepCurrentPath: true)
                        }
                        Button("Browse BotBooru") {
                            navManager.navigateToHubArchive(keepCurrentPath: true)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
    }
}

struct CharacterCardPreview: View {
    @Environment(\.appTheme) private var appTheme

    let card: CharacterCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = card.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .frame(maxWidth: 195)
                    .clipped()
            } else {
                // Placeholder image
                Rectangle()
                    .fill(appTheme.secondaryAction.color)
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(appTheme.secondaryText.color)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(appTheme.primaryText.color)

                Text(card.cardTagline ?? card.description ?? "No description available.")
                    .font(.caption)
                    .foregroundColor(appTheme.secondaryText.color)
                    .lineLimit(3)

                Spacer()

                HStack {
                    Text(card.tags?.prefix(3).joined(separator: ", ") ?? "")
                        .font(.caption2)
                        .foregroundColor(appTheme.secondaryText.color)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(appTheme.secondaryText.color)
                        Text("\(card.chats.count)")
                            .foregroundColor(appTheme.secondaryText.color)
                    }
                    .font(.caption)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(appTheme.secondaryBackgroundColor.color)
        .cornerRadius(12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
