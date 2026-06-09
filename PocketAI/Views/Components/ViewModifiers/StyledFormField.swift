import SwiftUI

public struct StyledFormField: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .themedFieldChrome()
    }
}

public extension View {
    func styledFormField() -> some View {
        modifier(StyledFormField())
    }
}
