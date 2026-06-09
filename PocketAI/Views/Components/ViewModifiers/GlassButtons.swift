import SwiftUI

public struct GlassCapsuleViewModifier: ViewModifier {
    @Environment(\.appTheme) private var appTheme

    private let size: CGFloat

    public init(size: CGFloat = 44) {
        self.size = size
    }

    public func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .frame(width: size, height: size)
            .foregroundStyle(appTheme.primaryText.color)
            .background(appTheme.secondaryBackgroundColor.color)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
    }
}

public extension View {
    func glassCapsule(size: CGFloat = 44) -> some View {
        modifier(GlassCapsuleViewModifier(size: size))
    }
}
