import SwiftUI

struct AvatarImage: View {
    @Environment(\.appTheme) private var appTheme

    let image: Image?
    let size: CGFloat

    var body: some View {
        if let image = image {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle() 
                .fill(appTheme.secondaryAction.color)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(appTheme.secondaryText.color)
                        .font(.title2)
                )
        }
    }
}
