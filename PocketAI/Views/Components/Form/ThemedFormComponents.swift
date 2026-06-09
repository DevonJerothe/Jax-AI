import SwiftUI
import UIKit

struct ThemedSectionHeader: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let subtitle: String?
    var titleFont: Font = .title2

    init(title: String, subtitle: String? = nil, titleFont: Font = .title2) {
        self.title = title
        self.subtitle = subtitle
        self.titleFont = titleFont
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(titleFont)
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

struct ThemedTextField: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled = true
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>?
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemedFieldLabel(title)

            textField
            .keyboardType(keyboardType)
            .autocorrectionDisabled(autocorrectionDisabled)
            .textInputAutocapitalization(autocapitalization)
            .foregroundStyle(appTheme.primaryText.color)
            .font(monospaced ? .system(.body, design: .monospaced) : .body)
            .themedFieldChrome()
        }
    }

    @ViewBuilder
    private var textField: some View {
        let field = TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundStyle(appTheme.secondaryText.color),
            axis: axis
        )

        if let lineLimit {
            field.lineLimit(lineLimit)
        } else {
            field
        }
    }
}

struct ThemedSecureField: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemedFieldLabel(title)

            SecureField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(appTheme.primaryText.color)
                .themedFieldChrome()
        }
    }
}

struct ThemedTextEditor: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemedFieldLabel(title)

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

struct ThemedOptionCard<Content: View>: View {
    @Environment(\.appTheme) private var appTheme

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .background(appTheme.secondaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ThemedToggleRow<Label: View>: View {
    @Environment(\.appTheme) private var appTheme

    @Binding var isOn: Bool
    let label: Label

    init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self._isOn = isOn
        self.label = label()
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            label
        }
        .tint(appTheme.tintColor.color)
    }
}

struct ThemedStepperRow: View {
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
        .tint(appTheme.tintColor.color)
    }
}

struct ThemedSliderRow: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    var value: Binding<Double>
    var range: ClosedRange<Double>
    var step: Double
    var displayValue: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .foregroundStyle(appTheme.primaryText.color)

                Spacer()

                Text(displayValue)
                    .font(.subheadline)
                    .foregroundStyle(appTheme.secondaryText.color)
            }

            Slider(value: value, in: range, step: step)
                .tint(appTheme.tintColor.color)
        }
    }
}

struct ThemedFieldLabel: View {
    @Environment(\.appTheme) private var appTheme

    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(appTheme.primaryText.color)
    }
}

private struct ThemedFieldChrome: ViewModifier {
    @Environment(\.appTheme) private var appTheme

    func body(content: Content) -> some View {
        content
            .padding()
            .foregroundStyle(appTheme.primaryText.color)
            .background(appTheme.secondaryBackgroundColor.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func themedFieldChrome() -> some View {
        modifier(ThemedFieldChrome())
    }
}
