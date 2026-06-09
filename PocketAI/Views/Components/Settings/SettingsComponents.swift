import SwiftUI

struct SettingsCard<Content: View>: View {
    @Environment(\.appTheme) private var appTheme

    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(appTheme.primaryText.color)
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appTheme.secondaryBackgroundColor.color)
            .cornerRadius(12)
        }
    }
}

struct SettingsNavigationRow: View {
    @Environment(\.appTheme) private var appTheme

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(appTheme.primaryText.color)
                .frame(width: 30, height: 30)
                .background(appTheme.secondaryAction.color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(appTheme.primaryText.color)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(appTheme.secondaryText.color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(appTheme.borderColor.color)
        }
        .contentShape(Rectangle())
    }
}

struct SamplerSlider: View {
    var title: String
    var value: Binding<Double> 
    var range: ClosedRange<Double>
    var step: Double
    var displayValue: String 

    var body: some View {
        ThemedSliderRow(
            title: title,
            value: value,
            range: range,
            step: step,
            displayValue: displayValue
        )
    }
}
