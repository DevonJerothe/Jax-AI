import SwiftUI

struct LoreBookPreview: View {
    @Environment(\.appTheme) private var appTheme

    let loreBook: LoreBookModel

    private var enabledEntries: Int {
        loreBook.entries.filter { $0.enabled ?? true }.count
    }

    private var descriptionText: String {
        guard let description = loreBook.description, !description.isEmpty else {
            return "No description available."
        }

        return description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: loreBook.isPrivate ? "book.closed.fill" : "book.closed")
                    .font(.title2)
                    .foregroundStyle(appTheme.tintColor.color)
                    .frame(width: 36, height: 36)
                    .background(appTheme.secondaryAction.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Text("\(loreBook.entries.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appTheme.secondaryText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appTheme.backgroundColor.color)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(loreBook.name)
                    .font(.headline)
                    .foregroundColor(appTheme.primaryText.color)
                    .lineLimit(2)

                Text(descriptionText)
                    .font(.caption)
                    .foregroundColor(appTheme.secondaryText.color)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            HStack {
                Label("\(enabledEntries) enabled", systemImage: "checkmark.circle")
                Spacer()
                Text("Depth \(loreBook.scanDepth)")
            }
            .font(.caption2)
            .foregroundStyle(appTheme.secondaryText.color)
        }
        .padding(14)
        .frame(maxWidth: 220, minHeight: 170, alignment: .topLeading)
        .background(appTheme.secondaryBackgroundColor.color)
        .cornerRadius(12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
