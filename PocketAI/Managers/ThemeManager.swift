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
        Color(
            uiColor: UIColor { traitCollection in
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
        primaryAction: ThemeColorPair(
            light: ThemeColor(94, 106, 210), dark: ThemeColor(142, 149, 255)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(220, 227, 245), dark: ThemeColor(45, 51, 72)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(216, 92, 92), dark: ThemeColor(255, 122, 122)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(247, 247, 250), dark: ThemeColor(17, 18, 23)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(27, 29, 39)),
        tintColor: ThemeColorPair(light: ThemeColor(108, 99, 255), dark: ThemeColor(168, 162, 255)),
        borderColor: ThemeColorPair(light: ThemeColor(227, 229, 234), dark: ThemeColor(42, 45, 56)),
        successColor: ThemeColorPair(
            light: ThemeColor(58, 155, 115), dark: ThemeColor(101, 214, 162)),
        warningColor: ThemeColorPair(
            light: ThemeColor(184, 132, 47), dark: ThemeColor(231, 182, 92)),
        primaryText: ThemeColorPair(light: ThemeColor(28, 29, 34), dark: ThemeColor(243, 244, 248)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(110, 115, 128), dark: ThemeColor(165, 169, 182)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(90, 78, 156), dark: ThemeColor(192, 183, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(40, 124, 118), dark: ThemeColor(142, 225, 214))
    )

    static let rosewood = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(174, 88, 111), dark: ThemeColor(244, 139, 169)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(246, 226, 232), dark: ThemeColor(64, 39, 48)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(204, 73, 73), dark: ThemeColor(255, 126, 126)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(250, 247, 247), dark: ThemeColor(20, 15, 18)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(31, 23, 28)),
        tintColor: ThemeColorPair(light: ThemeColor(194, 96, 127), dark: ThemeColor(255, 158, 188)),
        borderColor: ThemeColorPair(light: ThemeColor(234, 224, 226), dark: ThemeColor(53, 41, 47)),
        successColor: ThemeColorPair(
            light: ThemeColor(66, 150, 108), dark: ThemeColor(112, 218, 162)),
        warningColor: ThemeColorPair(
            light: ThemeColor(180, 122, 46), dark: ThemeColor(235, 181, 92)),
        primaryText: ThemeColorPair(light: ThemeColor(34, 27, 30), dark: ThemeColor(247, 240, 243)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(121, 103, 110), dark: ThemeColor(181, 163, 171)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(131, 83, 148), dark: ThemeColor(218, 170, 238)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(151, 89, 80), dark: ThemeColor(238, 164, 151))
    )

    static let graphiteMint = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(55, 125, 117), dark: ThemeColor(101, 214, 199)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(224, 238, 236), dark: ThemeColor(35, 54, 59)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(199, 76, 76), dark: ThemeColor(255, 132, 132)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(246, 248, 248), dark: ThemeColor(13, 17, 19)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(22, 29, 32)),
        tintColor: ThemeColorPair(light: ThemeColor(37, 150, 139), dark: ThemeColor(117, 235, 218)),
        borderColor: ThemeColorPair(light: ThemeColor(221, 226, 226), dark: ThemeColor(38, 47, 51)),
        successColor: ThemeColorPair(
            light: ThemeColor(52, 150, 104), dark: ThemeColor(100, 218, 154)),
        warningColor: ThemeColorPair(
            light: ThemeColor(176, 126, 42), dark: ThemeColor(232, 185, 88)),
        primaryText: ThemeColorPair(light: ThemeColor(25, 29, 31), dark: ThemeColor(239, 244, 244)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(101, 111, 114), dark: ThemeColor(159, 171, 175)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(68, 92, 155), dark: ThemeColor(158, 184, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(36, 126, 111), dark: ThemeColor(128, 226, 211))
    )

    static let shadowPine = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(62, 112, 92), dark: ThemeColor(102, 170, 139)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(222, 233, 228), dark: ThemeColor(29, 43, 39)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(183, 78, 72), dark: ThemeColor(231, 106, 98)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(246, 248, 247), dark: ThemeColor(8, 13, 12)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(16, 24, 22)),
        tintColor: ThemeColorPair(light: ThemeColor(70, 136, 110), dark: ThemeColor(126, 211, 174)),
        borderColor: ThemeColorPair(light: ThemeColor(220, 227, 224), dark: ThemeColor(33, 47, 43)),
        successColor: ThemeColorPair(
            light: ThemeColor(54, 145, 101), dark: ThemeColor(96, 215, 151)),
        warningColor: ThemeColorPair(
            light: ThemeColor(158, 124, 62), dark: ThemeColor(214, 174, 92)),
        primaryText: ThemeColorPair(light: ThemeColor(24, 31, 29), dark: ThemeColor(235, 242, 239)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(95, 112, 106), dark: ThemeColor(145, 166, 158)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(76, 96, 135), dark: ThemeColor(151, 178, 222)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(48, 118, 92), dark: ThemeColor(127, 218, 174))
    )

    static let stealthGraphite = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(73, 82, 96), dark: ThemeColor(105, 117, 134)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(229, 232, 235), dark: ThemeColor(31, 35, 41)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(174, 75, 75), dark: ThemeColor(220, 94, 94)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(247, 248, 249), dark: ThemeColor(10, 12, 15)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(18, 21, 26)),
        tintColor: ThemeColorPair(light: ThemeColor(88, 98, 116), dark: ThemeColor(128, 142, 162)),
        borderColor: ThemeColorPair(light: ThemeColor(222, 225, 229), dark: ThemeColor(35, 40, 48)),
        successColor: ThemeColorPair(
            light: ThemeColor(78, 137, 104), dark: ThemeColor(111, 176, 138)),
        warningColor: ThemeColorPair(
            light: ThemeColor(157, 121, 61), dark: ThemeColor(201, 160, 91)),
        primaryText: ThemeColorPair(light: ThemeColor(24, 27, 31), dark: ThemeColor(234, 237, 241)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(104, 111, 121), dark: ThemeColor(143, 153, 166)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(83, 93, 126), dark: ThemeColor(151, 164, 207)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(71, 112, 107), dark: ThemeColor(125, 174, 168))
    )

    static let slateNoir = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(67, 91, 132), dark: ThemeColor(112, 145, 204)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(224, 230, 239), dark: ThemeColor(28, 36, 50)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(187, 74, 82), dark: ThemeColor(238, 104, 115)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(246, 247, 250), dark: ThemeColor(7, 10, 15)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(15, 20, 29)),
        tintColor: ThemeColorPair(light: ThemeColor(76, 106, 159), dark: ThemeColor(132, 168, 235)),
        borderColor: ThemeColorPair(light: ThemeColor(221, 225, 232), dark: ThemeColor(30, 39, 54)),
        successColor: ThemeColorPair(
            light: ThemeColor(61, 139, 112), dark: ThemeColor(101, 205, 166)),
        warningColor: ThemeColorPair(
            light: ThemeColor(169, 124, 49), dark: ThemeColor(225, 178, 84)),
        primaryText: ThemeColorPair(light: ThemeColor(24, 28, 36), dark: ThemeColor(235, 240, 248)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(98, 108, 124), dark: ThemeColor(143, 158, 181)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(83, 78, 148), dark: ThemeColor(173, 168, 242)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(43, 119, 132), dark: ThemeColor(119, 211, 226))
    )

    static let oledAurora = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(94, 106, 210), dark: ThemeColor(132, 140, 255)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(220, 227, 245), dark: ThemeColor(22, 24, 36)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(216, 92, 92), dark: ThemeColor(255, 94, 105)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(247, 247, 250), dark: ThemeColor(0, 0, 0)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(11, 12, 18)),
        tintColor: ThemeColorPair(light: ThemeColor(108, 99, 255), dark: ThemeColor(159, 148, 255)),
        borderColor: ThemeColorPair(light: ThemeColor(227, 229, 234), dark: ThemeColor(28, 30, 42)),
        successColor: ThemeColorPair(
            light: ThemeColor(58, 155, 115), dark: ThemeColor(82, 234, 166)),
        warningColor: ThemeColorPair(
            light: ThemeColor(184, 132, 47), dark: ThemeColor(255, 191, 79)),
        primaryText: ThemeColorPair(light: ThemeColor(28, 29, 34), dark: ThemeColor(248, 249, 252)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(110, 115, 128), dark: ThemeColor(162, 166, 181)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(90, 78, 156), dark: ThemeColor(196, 187, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(40, 124, 118), dark: ThemeColor(105, 239, 224))
    )

    static let oledCyber = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(38, 126, 201), dark: ThemeColor(0, 191, 255)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(219, 238, 250), dark: ThemeColor(9, 28, 38)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(207, 70, 94), dark: ThemeColor(255, 77, 118)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(246, 249, 252), dark: ThemeColor(0, 0, 0)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(7, 12, 16)),
        tintColor: ThemeColorPair(light: ThemeColor(0, 139, 210), dark: ThemeColor(0, 220, 255)),
        borderColor: ThemeColorPair(light: ThemeColor(218, 229, 238), dark: ThemeColor(20, 42, 52)),
        successColor: ThemeColorPair(
            light: ThemeColor(39, 157, 113), dark: ThemeColor(0, 255, 171)),
        warningColor: ThemeColorPair(
            light: ThemeColor(185, 127, 36), dark: ThemeColor(255, 196, 68)),
        primaryText: ThemeColorPair(light: ThemeColor(20, 29, 36), dark: ThemeColor(245, 252, 255)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(91, 112, 126), dark: ThemeColor(136, 168, 181)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(103, 76, 174), dark: ThemeColor(190, 143, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(25, 126, 150), dark: ThemeColor(71, 235, 255))
    )

    static let oledEmber = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(194, 101, 43), dark: ThemeColor(255, 145, 69)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(246, 230, 216), dark: ThemeColor(39, 23, 14)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(196, 70, 62), dark: ThemeColor(255, 91, 82)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(250, 247, 244), dark: ThemeColor(0, 0, 0)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(15, 10, 7)),
        tintColor: ThemeColorPair(light: ThemeColor(214, 111, 49), dark: ThemeColor(255, 166, 86)),
        borderColor: ThemeColorPair(light: ThemeColor(235, 224, 216), dark: ThemeColor(43, 29, 21)),
        successColor: ThemeColorPair(
            light: ThemeColor(70, 143, 98), dark: ThemeColor(113, 221, 151)),
        warningColor: ThemeColorPair(
            light: ThemeColor(194, 128, 41), dark: ThemeColor(255, 194, 73)),
        primaryText: ThemeColorPair(light: ThemeColor(35, 28, 23), dark: ThemeColor(255, 246, 238)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(120, 101, 88), dark: ThemeColor(183, 159, 143)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(146, 87, 57), dark: ThemeColor(255, 176, 128)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(106, 111, 64), dark: ThemeColor(205, 214, 113))
    )

    static let violetBloom = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(124, 85, 218), dark: ThemeColor(177, 137, 255)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(235, 226, 255), dark: ThemeColor(48, 34, 74)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(215, 76, 101), dark: ThemeColor(255, 116, 148)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(250, 247, 255), dark: ThemeColor(18, 13, 26)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(29, 22, 42)),
        tintColor: ThemeColorPair(light: ThemeColor(146, 91, 255), dark: ThemeColor(199, 163, 255)),
        borderColor: ThemeColorPair(light: ThemeColor(232, 224, 245), dark: ThemeColor(53, 42, 70)),
        successColor: ThemeColorPair(
            light: ThemeColor(48, 159, 116), dark: ThemeColor(98, 226, 165)),
        warningColor: ThemeColorPair(
            light: ThemeColor(190, 130, 40), dark: ThemeColor(247, 190, 80)),
        primaryText: ThemeColorPair(light: ThemeColor(33, 26, 43), dark: ThemeColor(248, 243, 255)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(113, 99, 132), dark: ThemeColor(178, 161, 204)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(104, 72, 185), dark: ThemeColor(196, 166, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(31, 139, 141), dark: ThemeColor(108, 231, 234))
    )

    static let oceanPop = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(20, 130, 196), dark: ThemeColor(64, 190, 255)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(220, 242, 250), dark: ThemeColor(21, 49, 65)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(210, 74, 86), dark: ThemeColor(255, 118, 130)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(246, 251, 253), dark: ThemeColor(8, 18, 25)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(15, 31, 42)),
        tintColor: ThemeColorPair(light: ThemeColor(0, 154, 214), dark: ThemeColor(83, 214, 255)),
        borderColor: ThemeColorPair(light: ThemeColor(218, 233, 240), dark: ThemeColor(32, 57, 70)),
        successColor: ThemeColorPair(
            light: ThemeColor(42, 163, 116), dark: ThemeColor(92, 230, 164)),
        warningColor: ThemeColorPair(
            light: ThemeColor(189, 130, 36), dark: ThemeColor(247, 195, 77)),
        primaryText: ThemeColorPair(light: ThemeColor(18, 34, 44), dark: ThemeColor(240, 250, 255)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(84, 111, 126), dark: ThemeColor(148, 181, 196)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(73, 88, 180), dark: ThemeColor(161, 176, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(0, 133, 145), dark: ThemeColor(89, 229, 239))
    )

    static let sakuraPop = AppTheme(
        primaryAction: ThemeColorPair(
            light: ThemeColor(219, 85, 139), dark: ThemeColor(255, 135, 188)),
        secondaryAction: ThemeColorPair(
            light: ThemeColor(252, 225, 238), dark: ThemeColor(66, 32, 50)),
        destructiveAction: ThemeColorPair(
            light: ThemeColor(212, 69, 83), dark: ThemeColor(255, 112, 126)),
        backgroundColor: ThemeColorPair(
            light: ThemeColor(255, 247, 251), dark: ThemeColor(24, 12, 20)),
        secondaryBackgroundColor: ThemeColorPair(
            light: ThemeColor(255, 255, 255), dark: ThemeColor(38, 20, 32)),
        tintColor: ThemeColorPair(light: ThemeColor(238, 99, 157), dark: ThemeColor(255, 158, 207)),
        borderColor: ThemeColorPair(light: ThemeColor(243, 220, 231), dark: ThemeColor(61, 35, 49)),
        successColor: ThemeColorPair(
            light: ThemeColor(49, 156, 111), dark: ThemeColor(96, 225, 160)),
        warningColor: ThemeColorPair(
            light: ThemeColor(191, 129, 43), dark: ThemeColor(246, 190, 79)),
        primaryText: ThemeColorPair(light: ThemeColor(42, 25, 34), dark: ThemeColor(255, 241, 248)),
        secondaryText: ThemeColorPair(
            light: ThemeColor(128, 91, 108), dark: ThemeColor(194, 152, 172)),
        botQuoteText: ThemeColorPair(
            light: ThemeColor(139, 75, 181), dark: ThemeColor(221, 160, 255)),
        userQuoteText: ThemeColorPair(
            light: ThemeColor(193, 82, 114), dark: ThemeColor(255, 157, 184))
    )
}

public enum AvailableThemes: String, CaseIterable, Identifiable {
    case defaultTheme = "Default"
    case rosewood = "Rosewood"
    case graphiteMint = "Graphite Mint"
    case shadowPine = "Shadow Pine"
    case stealthGraphite = "Stealth Graphite"
    case slateNoir = "Slate Noir"
    case oledAurora = "OLED Aurora"
    case oledCyber = "OLED Cyber"
    case oledEmber = "OLED Ember"
    case violetBloom = "Violet Bloom"
    case oceanPop = "Ocean Pop"
    case sakuraPop = "Sakura Pop"

    public var id: String { rawValue }

    var theme: AppTheme {
        switch self {
        case .defaultTheme:
            return AppTheme.defaultTheme
        case .rosewood:
            return AppTheme.rosewood
        case .graphiteMint:
            return AppTheme.graphiteMint
        case .shadowPine:
            return AppTheme.shadowPine
        case .stealthGraphite:
            return AppTheme.stealthGraphite
        case .slateNoir:
            return AppTheme.slateNoir
        case .oledAurora:
            return AppTheme.oledAurora
        case .oledCyber:
            return AppTheme.oledCyber
        case .oledEmber:
            return AppTheme.oledEmber
        case .violetBloom:
            return AppTheme.violetBloom
        case .oceanPop:
            return AppTheme.oceanPop
        case .sakuraPop:
            return AppTheme.sakuraPop
        }
    }

    static func themeCase(for theme: AppTheme) -> AvailableThemes {
        AvailableThemes.allCases.first(where: { $0.theme == theme }) ?? .defaultTheme
    }
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
