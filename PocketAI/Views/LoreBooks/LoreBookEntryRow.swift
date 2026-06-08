import SwiftUI

struct LoreBookEntryRow: View {
    @Environment(\.appTheme) private var appTheme

    let entry: LoreBookEntryModel
    @Binding var isEnabled: Bool
    let onSelect: () -> Void

    private var displayKeys: [String] {
        Array(entry.keys.prefix(3).filter { !$0.isEmpty })
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onSelect) {
                rowContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(appTheme.tintColor.color)
        }
        .padding()
        .background(appTheme.secondaryBackgroundColor.color)
        .cornerRadius(12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.name.isEmpty ? "Untitled Entry" : entry.name)
                .font(.headline)
                .foregroundStyle(appTheme.primaryText.color)
                .lineLimit(1)

            keyChips

            Text(entry.content.isEmpty ? "No content" : entry.content)
                .font(.caption)
                .foregroundStyle(appTheme.secondaryText.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var keyChips: some View {
        if displayKeys.isEmpty {
            Text("No keys")
                .font(.caption2)
                .foregroundStyle(appTheme.secondaryText.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(appTheme.backgroundColor.color)
                .clipShape(Capsule())
        } else {
            HStack(spacing: 6) {
                ForEach(Array(displayKeys.enumerated()), id: \.offset) { _, key in
                    Text(key)
                        .font(.caption2)
                        .foregroundStyle(appTheme.primaryText.color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: 110)
                        .background(appTheme.backgroundColor.color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
