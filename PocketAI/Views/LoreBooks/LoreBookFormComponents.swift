import SwiftUI
import UIKit

struct LoreBookSectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        ThemedSectionHeader(title: title, subtitle: subtitle)
    }
}

struct LoreBookTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        ThemedTextField(
            title: title,
            placeholder: placeholder,
            text: $text,
            keyboardType: keyboardType,
            autocapitalization: autocapitalization
        )
    }
}

struct LoreBookTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let height: CGFloat

    var body: some View {
        ThemedTextEditor(
            title: title,
            placeholder: placeholder,
            text: $text,
            height: height
        )
    }
}

struct LoreBookStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        ThemedStepperRow(title: title, value: $value, range: range)
    }
}
