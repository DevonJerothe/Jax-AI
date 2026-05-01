import SwiftUI

public struct StyledFormField: ViewModifier {
    @Environment(\.appTheme) private var appTheme

    public func body(content: Content) -> some View {
        content
            .padding()
            .foregroundStyle(appTheme.primaryText.color)
            .background(appTheme.secondaryBackgroundColor.color)
            .cornerRadius(12)
    }
}

public extension View {
    func styledFormField() -> some View {
        modifier(StyledFormField())
    }
}
