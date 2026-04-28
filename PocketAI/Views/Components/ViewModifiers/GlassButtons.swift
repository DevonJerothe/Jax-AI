import SwiftUI

public struct GlassCapsuleViewModifier: ViewModifier {
    private let size: CGFloat

    public init(size: CGFloat = 44) {
        self.size = size
    }

    public func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .frame(width: size, height: size)
            .background(Color(.systemGray6).opacity(0.6))
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