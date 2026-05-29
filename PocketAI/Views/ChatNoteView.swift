import SwiftUI

struct ChatNoteView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.appTheme) private var appTheme

    @State private var viewModel: ChatViewModel
    @State private var noteText: String = ""
    @State private var noteDepthValue: Int = 1
    @State private var noteInjectInMemory: Bool = false

    init(chatID: UUID) {
        _viewModel = State(initialValue: ChatViewModel(chatID: chatID))
    }

    private var maxNoteDepth: Int {
        max(1, viewModel.model?.messages.count ?? 1)
    }

    private var canAdd: Bool {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        AppSheetContainer(initialHeight: 560) {
            VStack(alignment: .leading, spacing: 20) {
                AppSheetHeader(
                    title: "Add Note",
                    subtitle: "Enter a note to inject into the chat prompt."
                )

                AppSheetEditor(
                    title: "Note Text",
                    placeholder: "Chat note...",
                    text: $noteText,
                    height: 240
                )

                AppSheetOptionCard {
                    Toggle(isOn: $noteInjectInMemory) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inject in Memory")
                                .foregroundStyle(appTheme.primaryText.color)

                            Text("Memory notes are injected before chat messages.")
                                .font(.caption)
                                .foregroundStyle(appTheme.secondaryText.color)
                        }
                    }
                    .tint(appTheme.tintColor.color)

                    if noteInjectInMemory == false {
                        Stepper(value: $noteDepthValue, in: 1...maxNoteDepth) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Note Depth")
                                    .foregroundStyle(appTheme.primaryText.color)

                                Text("\(noteDepthValue)")
                                    .font(.caption)
                                    .foregroundStyle(appTheme.secondaryText.color)
                            }
                        }
                        .tint(appTheme.tintColor.color)
                    }
                }
                .animation(.snappy(duration: 0.2), value: noteInjectInMemory)

                actionRow
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Spacer()

            Button {
                navManager.presentedSheet = nil
            } label: {
                Text("Cancel")
                    .fontWeight(.semibold)
                    .frame(minWidth: 84)
            }
            .buttonStyle(AppSheetButtonStyle(kind: .secondary))

            Button {
                submitNote()
            } label: {
                Text("Add")
                    .fontWeight(.semibold)
                    .frame(minWidth: 84)
            }
            .buttonStyle(AppSheetButtonStyle(kind: .primary))
            .disabled(canAdd == false)
        }
    }

    private func submitNote() {
        let text = noteText
        let depth = noteDepthValue
        let injectInMemory = noteInjectInMemory

        navManager.presentedSheet = nil
        Task {
            await viewModel.addNote(
                text: text,
                depth: depth,
                injectInMemory: injectInMemory
            )
        }
    }
}
