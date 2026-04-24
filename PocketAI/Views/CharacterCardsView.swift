import SwiftUI

struct CharacterCardsView: View {
    @Environment(NavigationManager.self) var navManager
    @State var viewModel: CharacterCardsViewModel = CharacterCardsViewModel()
    
    private let columns: [GridItem] = [
        GridItem(.flexible(maximum: 200), spacing: 16),
        GridItem(.flexible(maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.characterCards, id: \.self) { card in
                        CharacterCardPreview(card: card)
                            .onTapGesture {
                                navManager.navigateToCharacter(characterID: card.id, keepCurrentPath: true)
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
        .navigationTitle("My Characters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Create From Scratch") {
                        navManager.navigateToNewChat(keepCurrentPath: true, createCharacterCard: true)
                    }
                    Button("Import from ChubAI") {
                        navManager.navigateToChubImport(keepCurrentPath: true)
                    }
                    Button("Browse the Hub") {
                        navManager.navigateToHubArchive(keepCurrentPath: true) 
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
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(card.cardTagline ?? card.description ?? "No description available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                Spacer()
                
                HStack {
                    Text(card.tags?.prefix(3).joined(separator: ", ") ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        Text("\(card.chats.count)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
