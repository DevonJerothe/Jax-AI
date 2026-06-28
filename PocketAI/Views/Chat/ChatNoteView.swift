import SwiftUI

struct ChatNoteView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: ChatViewModel
    private let noteID: UUID?

    @State private var noteText: String = ""
    @State private var noteDepthValue: Int = 1
    @State private var noteInjectInMemory: Bool = false

    init(chatID: UUID, noteID: UUID? = nil) {
        self.noteID = noteID
        _viewModel = State(initialValue: ChatViewModel(chatID: chatID))
    }

    private var isEditing: Bool {
        noteID != nil
    }

    private var canSubmit: Bool {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        AppSheetContainer(initialHeight: 560) {
            VStack(alignment: .leading, spacing: 20) {
                AppSheetHeader(
                    title: isEditing ? "Edit Note" : "Add Note",
                    subtitle: "Enter a note to inject into the chat prompt."
                )

                AppSheetEditor(
                    title: "Note Text",
                    placeholder: "Chat note...",
                    text: $noteText,
                    height: 240
                )

                AppSheetOptionCard {
                    ThemedToggleRow(isOn: $noteInjectInMemory) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inject in Memory")
                                .foregroundStyle(appTheme.primaryText.color)

                            Text("Memory notes are injected before chat messages.")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }

                    if noteInjectInMemory == false {
                        ThemedStepperRow(title: "Note Depth", value: $noteDepthValue, range: 1...Int.max)
                    }
                }
                .animation(.snappy(duration: 0.2), value: noteInjectInMemory)

                actionRow
            }
        }
        .onAppear {
            loadExistingNote()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if isEditing {
                Button {
                    deleteNote()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(appTheme.destructiveAction.color)
                .background(appTheme.secondaryBackgroundColor.color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Delete Note")
            }

            Spacer()

            Button {
                navManager.presentedSheet = nil
            } label: {
                Text("Cancel")
                    .foregroundColor(appTheme.primaryText.color)
                    .fontWeight(.semibold)
                    .frame(minWidth: 84)
            }
            .buttonStyle(AppSheetButtonStyle(kind: .secondary))

            Button {
                submitNote()
            } label: {
                Text(isEditing ? "Update" : "Add")
                    .foregroundColor(appTheme.primaryText.color)
                    .fontWeight(.semibold)
                    .frame(minWidth: 84)
            }
            .buttonStyle(AppSheetButtonStyle(kind: .primary))
            .disabled(canSubmit == false)
        }
    }

    private func loadExistingNote() {
        guard let noteID,
              let note = viewModel.model?.chatNotes.first(where: { $0.id == noteID })
        else {
            return
        }

        noteText = note.note
        noteDepthValue = max(1, note.depth)
        noteInjectInMemory = note.injectInMemory
    }

    private func submitNote() {
        let text = noteText
        let depth = noteDepthValue
        let injectInMemory = noteInjectInMemory

        navManager.presentedSheet = nil
        Task {
            if let noteID {
                await viewModel.updateNote(
                    noteID: noteID,
                    text: text,
                    depth: depth,
                    injectInMemory: injectInMemory
                )
            } else {
                await viewModel.addNote(
                    text: text,
                    depth: depth,
                    injectInMemory: injectInMemory
                )
            }
        }
    }

    private func deleteNote() {
        guard let noteID else {
            return
        }

        navManager.presentedSheet = nil
        Task {
            await viewModel.deleteNote(noteID: noteID)
        }
    }
}
