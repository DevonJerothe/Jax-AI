import SwiftUI

struct LoreBookEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var appTheme
    @Binding var entry: LoreBookEntryModel

    let onDelete: () -> Void

    @State private var keysText = ""
    @State private var secondaryKeysText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    entrySection
                    keysSection
                    contentSection
                    advancedSection
                    deleteButton
                }
                .padding(.vertical, 24)
            }
            .background(appTheme.backgroundColor.color)
            .navigationTitle(entry.name.isEmpty ? "Entry" : entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        commitKeys()
                        dismiss()
                    }
                }
            }
            .onAppear {
                keysText = entry.keys.joined(separator: ", ")
                secondaryKeysText = entry.secondaryKeys.joined(separator: ", ")
            }
            .onDisappear {
                commitKeys()
            }
        }
    }

    private var entrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoreBookSectionHeader(
                title: "Entry",
                subtitle: "Define when this entry is active and how it is included."
            )

            LoreBookTextField(
                title: "Name",
                placeholder: "Entry name",
                text: $entry.name,
                autocapitalization: .words
            )

            AppSheetOptionCard {
                Toggle(
                    isOn: Binding(
                        get: { entry.enabled ?? true },
                        set: { entry.enabled = $0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enabled")
                            .foregroundStyle(appTheme.primaryText.color)

                        Text("Include this entry when its keys match.")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                }
                .tint(appTheme.tintColor.color)
            }

            AppSheetOptionCard {
                Toggle(
                    isOn: Binding(
                        get: { entry.constant ?? false },
                        set: { entry.constant = $0 }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Constant")
                            .foregroundStyle(appTheme.primaryText.color)

                        Text("Always include this entry while the lorebook is active.")
                            .font(.caption)
                            .foregroundStyle(appTheme.secondaryText.color)
                    }
                }
                .tint(appTheme.tintColor.color)
            }
        }
        .padding(.horizontal, 16)
    }

    private var keysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoreBookSectionHeader(
                title: "Keys",
                subtitle: "Use comma separated keys to trigger this entry."
            )

            keyEditor("Primary Keys", text: $keysText)
            keyEditor("Secondary Keys", text: $secondaryKeysText)

            AppSheetOptionCard {
                Toggle(
                    isOn: Binding(
                        get: { entry.caseSensitive ?? false },
                        set: { entry.caseSensitive = $0 }
                    )
                ) {
                    Text("Case Sensitive")
                        .foregroundStyle(appTheme.primaryText.color)
                }
                .tint(appTheme.tintColor.color)
            }
        }
        .padding(.horizontal, 16)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoreBookSectionHeader(
                title: "Content",
                subtitle: "Write the full context inserted when this entry is selected."
            )

            LoreBookTextEditor(
                title: "Entry Content",
                placeholder: "Lorebook content...",
                text: $entry.content,
                height: 260
            )
        }
        .padding(.horizontal, 16)
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoreBookSectionHeader(title: "Advanced")

            AppSheetOptionCard {
                LoreBookStepperRow(
                    title: "Order",
                    value: optionalIntBinding(\.order),
                    range: -1000...1000
                )
                LoreBookStepperRow(
                    title: "Position",
                    value: optionalIntBinding(\.position),
                    range: 0...10
                )
                LoreBookStepperRow(
                    title: "Depth",
                    value: optionalIntBinding(\.depth),
                    range: 0...50
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            Label("Delete Entry", systemImage: "trash")
                .padding(.horizontal, 16)
        }
        .foregroundStyle(appTheme.destructiveAction.color)
    }

    private func keyEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(appTheme.primaryText.color)

            TextField("Comma separated keys", text: text, axis: .vertical)
                .lineLimit(2...5)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(appTheme.primaryText.color)
                .padding()
                .background(appTheme.secondaryBackgroundColor.color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func optionalIntBinding(_ keyPath: WritableKeyPath<LoreBookEntryModel, Int?>)
        -> Binding<Int>
    {
        Binding {
            entry[keyPath: keyPath] ?? 0
        } set: { value in
            entry[keyPath: keyPath] = value
        }
    }

    private func commitKeys() {
        entry.keys = keys(from: keysText)
        entry.secondaryKeys = keys(from: secondaryKeysText)
    }

    private func keys(from text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
