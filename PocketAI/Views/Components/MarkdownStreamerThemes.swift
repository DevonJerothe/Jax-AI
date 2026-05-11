import SwiftUI 
import MarkdownStreamer

struct MarkdownStreamerSettings {
    static func defaultTheme(appTheme: AppTheme, actor: MessageActor) -> MarkdownTheme {
        return MarkdownTheme(
            bodyFont: .body,
            bodyColor: appTheme.primaryText.color,
            headingFonts: [
                1: .title.bold(),
                2: .title2.bold(),
                3: .headline
            ],
            headingColor: appTheme.primaryText.color,
            boldFont: .body.bold(),
            inlineCodeFont: .system(.body, design: .monospaced),
            inlineCodeForeground: .gray,
            inlineCodeBackground: .secondary.opacity(0.14),
            quoteHighlightFont: .body.italic(),
            quoteHighlightForeground: actor == .user ? appTheme.userQuoteText.color : appTheme.botQuoteText.color,
            codeBlockBackground: .black.opacity(0.88),
            regexHighlights: [
                .standardQuotedSpeech
            ]
        )
    }
}