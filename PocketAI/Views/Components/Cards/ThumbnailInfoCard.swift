import SwiftUI

struct ThumbnailInfoCard: View {
    @Environment(\.appTheme) private var appTheme

    let imageURL: URL?
    let title: String
    let subtitle: String
    let leadingMetadata: String
    let trailingMetadata: String
    var fallbackSystemImage = "photo"
    var imageHeight: CGFloat = 150
    var maxImageWidth: CGFloat = 195

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(appTheme.primaryText.color)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
                    .lineLimit(3)

                Spacer()

                HStack {
                    Text(leadingMetadata)
                        .font(.caption2)
                        .foregroundStyle(appTheme.secondaryText.color)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Text(trailingMetadata)
                        .font(.caption2)
                        .foregroundStyle(appTheme.secondaryText.color)
                        .lineLimit(3)
                }
            }
            .padding([.leading, .trailing, .bottom], 12)
            .padding(.top, 8)
        }
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { state in
                switch state {
                case .empty:
                    loadingThumbnail
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: imageHeight)
                        .frame(maxWidth: maxImageWidth)
                        .clipped()
                case .failure:
                    fallbackThumbnail
                @unknown default:
                    fallbackThumbnail
                }
            }
        } else {
            fallbackThumbnail
        }
    }

    private var loadingThumbnail: some View {
        HStack {
            Spacer()
            LoadingIndicator(size: 30)
            Spacer()
        }
        .frame(height: imageHeight)
    }

    private var fallbackThumbnail: some View {
        Rectangle()
            .fill(appTheme.secondaryAction.color)
            .frame(height: imageHeight)
            .overlay {
                Image(systemName: fallbackSystemImage)
                    .font(.largeTitle)
                    .foregroundStyle(appTheme.secondaryText.color)
            }
    }
}
