import SwiftStreamingMarkdown
import SwiftUI
import UIKit

struct ChatMarkdownRenderConfig {
    static func renderConfig(appTheme: AppTheme, actor: MessageActor) -> MarkdownRenderConfig {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let bodyFonts = fontSet(for: bodyFont)
        let headingFont = fontSet(for: .preferredFont(forTextStyle: .headline), weight: .semibold)
        let inlineCodeFont = UIFont.monospacedSystemFont(
            ofSize: bodyFont.pointSize,
            weight: .regular
        )
        let primaryText = appTheme.primaryText.color

        let paragraphStyle = MarkdownRenderConfig.MarkdownTextStyle(
            textFonts: bodyFonts,
            textColor: primaryText
        )
        let headingStyle = MarkdownRenderConfig.MarkdownHeadingTextStyle(
            h1Font: fontSet(for: .preferredFont(forTextStyle: .title1), weight: .bold),
            h2Font: fontSet(for: .preferredFont(forTextStyle: .title2), weight: .bold),
            h3Font: headingFont,
            h4Font: headingFont,
            h5Font: headingFont,
            h6Font: headingFont,
            textColor: primaryText
        )
        let inlineStyle = MarkdownRenderConfig.MarkdownInlineTextStyle(
            boldTextColor: primaryText,
            linkTextFont: bodyFont,
            linkTextColor: appTheme.tintColor.color,
            codeTextFont: inlineCodeFont,
            codeTextColor: .gray,
            codeBackgroundColor: .secondary.opacity(0.14),
            codeUnderlineColor: .clear
        )
        let tableStyle = MarkdownRenderConfig.MarkdownTableTextStyle(
            textFonts: bodyFonts,
            headerTextColor: primaryText,
            regularTextColor: primaryText,
            headerBackgroundColor: appTheme.secondaryBackgroundColor.color.opacity(0.8),
            borderColor: appTheme.borderColor.color,
            actionButtonColor: appTheme.tintColor.color
        )
        let quoteColor = actor == .user ? appTheme.userQuoteText.color : appTheme.botQuoteText.color

        return MarkdownRenderConfig.default
            .withParagraphStyle(value: paragraphStyle)
            .withOrderedListStyle(value: paragraphStyle)
            .withBlockQuoteStyle(value: paragraphStyle)
            .withHeadingStyle(value: headingStyle)
            .withInlineStyle(value: inlineStyle)
            .withTableStyle(value: tableStyle)
            .withRegexHighlights(value: [.standardQuotedSpeech])
            .withQuoteHighlightStyle(
                font: bodyFont.withSymbolicTraits(.traitItalic) ?? bodyFont,
                color: quoteColor
            )
    }

    private static func fontSet(
        for font: UIFont,
        weight: UIFont.Weight? = nil,
        lineHeight: CGFloat? = nil
    ) -> TextFonts {
        let normal = weight.map { UIFont.systemFont(ofSize: font.pointSize, weight: $0) } ?? font

        return TextFonts(
            normal: normal,
            italic: normal.withSymbolicTraits(.traitItalic),
            bold: normal.withSymbolicTraits(.traitBold),
            boldItalic: normal.withSymbolicTraits([.traitBold, .traitItalic]),
            preferredLetterSpacing: nil,
            preferredLineHeight: lineHeight
        )
    }
}

private extension UIFont {
    func withSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return nil
        }

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
