import SwiftUI

struct ChatNotesView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: ChatViewModel

    init(chatID: UUID) {
        _viewModel = State(initialValue: ChatViewModel(chatID: chatID))
    }

    private var memoryNotes: [ChatNoteModel] {
        (viewModel.model?.chatNotes ?? [])
            .filter(\.injectInMemory)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var depthNotes: [ChatNoteModel] {
        (viewModel.model?.chatNotes ?? [])
            .filter { $0.injectInMemory == false }
            .sorted {
                if $0.depth == $1.depth {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.depth < $1.depth
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if memoryNotes.isEmpty == false {
                    noteSection(title: "Memory Injected Notes", notes: memoryNotes)
                }

                if depthNotes.isEmpty == false {
                    noteSection(title: "Depth Injected Notes", notes: depthNotes)
                }

                if memoryNotes.isEmpty && depthNotes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Notes added to this chat will appear here.")
                    )
                    .foregroundStyle(appTheme.secondaryText.color)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(appTheme.backgroundColor.color)
        .navigationTitle("Chat Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navManager.showChatNoteView(chatID: viewModel.chatID)
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(appTheme.primaryText.color)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func noteSection(title: String, notes: [ChatNoteModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(appTheme.primaryText.color)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(notes, id: \.id) { note in
                    Button {
                        navManager.showChatNoteView(chatID: viewModel.chatID, noteID: note.id)
                    } label: {
                        ChatNoteRow(note: note)
                    }
                    .buttonStyle(.plain)

                    if note.id != notes.last?.id {
                        Divider()
                            .overlay(appTheme.borderColor.color.opacity(0.35))
                            .padding(.leading, 16)
                    }
                }
            }
            .background(appTheme.secondaryBackgroundColor.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct ChatNoteRow: View {
    @Environment(\.appTheme) private var appTheme

    let note: ChatNoteModel

    private var detailText: String {
        note.injectInMemory ? "Memory Injection" : "Depth \(note.depth)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.note)
                    .font(.body)
                    .foregroundStyle(appTheme.primaryText.color)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(appTheme.secondaryText.color)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
