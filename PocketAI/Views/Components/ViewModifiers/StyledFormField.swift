import SwiftUI

public struct StyledFormField: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemGray6).opacity(0.6))
            .cornerRadius(12)
    }
}

public extension View {
    func styledFormField() -> some View {
        modifier(StyledFormField())
    }
}
