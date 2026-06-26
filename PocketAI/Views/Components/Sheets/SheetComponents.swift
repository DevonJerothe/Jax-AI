import SwiftUI
import UIKit

struct AppSheetContainer<Content: View>: View {
    @Environment(\.appTheme) private var appTheme

    private let minHeight: CGFloat
    private let maxScreenRatio: CGFloat
    private let content: Content

    @State private var sheetHeight: CGFloat

    init(
        initialHeight: CGFloat = 620,
        minHeight: CGFloat = 360,
        maxScreenRatio: CGFloat = 0.9,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.maxScreenRatio = maxScreenRatio
        self.content = content()
        self._sheetHeight = State(initialValue: initialHeight)
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: AppSheetHeightPreferenceKey.self, value: proxy.size.height)
                    }
                }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(appTheme.backgroundColor.color)
        .onPreferenceChange(AppSheetHeightPreferenceKey.self) { height in
            sheetHeight = min(
                max(height, minHeight), UIApplication.currentScreenHeight * maxScreenRatio)
        }
        .presentationDetents([.height(sheetHeight)])
    }
}

private struct AppSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 620

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AppSheetHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        ThemedSectionHeader(title: title, subtitle: subtitle)
    }
}

struct AppSheetField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ThemedTextField(
            title: title,
            placeholder: placeholder,
            text: $text,
            autocapitalization: .never
        )
    }
}

struct AppSheetEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 260

    var body: some View {
        ThemedTextEditor(
            title: title,
            placeholder: placeholder,
            text: $text,
            height: height
        )
    }
}

struct AppSheetOptionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ThemedOptionCard {
            content
        }
    }
}

struct AppSheetButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var appTheme
    @Environment(\.isEnabled) private var isEnabled

    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .frame(height: 44)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            appTheme.primaryText.color
        case .secondary:
            appTheme.secondaryText.color
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary:
            appTheme.primaryAction.color
        case .secondary:
            appTheme.secondaryBackgroundColor.color
        }
    }
}
