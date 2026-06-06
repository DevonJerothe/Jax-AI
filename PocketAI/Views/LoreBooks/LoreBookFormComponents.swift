import SwiftUI
import UIKit

struct LoreBookSectionHeader: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(appTheme.primaryText.color)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(appTheme.secondaryText.color)
            }
        }
    }
}

struct LoreBookTextField: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(appTheme.primaryText.color)

            TextField(
                "", text: $text,
                prompt: Text(placeholder).foregroundStyle(appTheme.secondaryText.color)
            )
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(autocapitalization)
            .foregroundStyle(appTheme.primaryText.color)
            .padding()
            .background(appTheme.secondaryBackgroundColor.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct LoreBookTextEditor: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let placeholder: String
    @Binding var text: String
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(appTheme.primaryText.color)

            EnhancedTextEditor(
                text: $text,
                placeholder: placeholder,
                maxHeight: height,
                minHeight: height,
                textColor: UIColor(appTheme.primaryText.color),
                placeholderColor: UIColor(appTheme.secondaryText.color)
            )
            .frame(height: height)
            .foregroundStyle(appTheme.primaryText.color)
            .background(appTheme.secondaryBackgroundColor.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct LoreBookStepperRow: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .foregroundStyle(appTheme.primaryText.color)
                Spacer()
                Text("\(value)")
                    .foregroundStyle(appTheme.secondaryText.color)
            }
        }
    }
}
