import Foundation
import SwiftUI
import UIKit

struct AppTheme: Codable, Equatable, Sendable {
    var primaryAction: ThemeColorPair
    var secondaryAction: ThemeColorPair
    var destructiveAction: ThemeColorPair
    var backgroundColor: ThemeColorPair
    var secondaryBackgroundColor: ThemeColorPair
    var tintColor: ThemeColorPair
    var borderColor: ThemeColorPair
    var successColor: ThemeColorPair
    var warningColor: ThemeColorPair

    // Text Colors 
    var primaryText: ThemeColorPair
    var secondaryText: ThemeColorPair
    var botQuoteText: ThemeColorPair
    var userQuoteText: ThemeColorPair
}

struct ThemeColorPair: Codable, Equatable, Sendable {
    var light: ThemeColor 
    var dark: ThemeColor

    var color: Color {
        Color(uiColor: UIColor { traitCollection in
            let themeColor = traitCollection.userInterfaceStyle == .dark ? dark : light
            return themeColor.uiColor
        })
    }

    func color(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dark.color : light.color
    }
}

// helper struct so we can init color a bit easier
struct ThemeColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1.0

    init(
        _ red: Double,
        _ green: Double,
        _ blue: Double,
        opacity: Double = 1.0
    ) {
        self.red = red / 255.0
        self.green = green / 255.0
        self.blue = blue / 255.0
        self.opacity = opacity
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: opacity)
    }
}

// MARK: - Default Theme 
extension AppTheme {
    // soft aurora
    static let defaultTheme = AppTheme(
        primaryAction: ThemeColorPair(light: ThemeColor(94, 106, 210), dark: ThemeColor(142, 149, 255)),
        secondaryAction: ThemeColorPair(light: ThemeColor(220, 227, 245), dark: ThemeColor(45, 51, 72)),
        destructiveAction: ThemeColorPair(light: ThemeColor(216, 92, 92), dark: ThemeColor(255, 122, 122)),
        backgroundColor: ThemeColorPair(light: ThemeColor(247, 247, 250), dark: ThemeColor(17, 18, 23)),
        secondaryBackgroundColor: ThemeColorPair(light: ThemeColor(255, 255, 255), dark: ThemeColor(27, 29, 39)),
        tintColor: ThemeColorPair(light: ThemeColor(108, 99, 255), dark: ThemeColor(168, 162, 255)),
        borderColor: ThemeColorPair(light: ThemeColor(227, 229, 234), dark: ThemeColor(42, 45, 56)),
        successColor: ThemeColorPair(light: ThemeColor(58, 155, 115), dark: ThemeColor(101, 214, 162)),
        warningColor: ThemeColorPair(light: ThemeColor(184, 132, 47), dark: ThemeColor(231, 182, 92)),
        primaryText: ThemeColorPair(light: ThemeColor(28, 29, 34), dark: ThemeColor(243, 244, 248)),
        secondaryText: ThemeColorPair(light: ThemeColor(110, 115, 128), dark: ThemeColor(165, 169, 182)),
        botQuoteText: ThemeColorPair(light: ThemeColor(90, 78, 156), dark: ThemeColor(192, 183, 255)),
        userQuoteText: ThemeColorPair(light: ThemeColor(40, 124, 118), dark: ThemeColor(142, 225, 214))
    )
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.defaultTheme
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
