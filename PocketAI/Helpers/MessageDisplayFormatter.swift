import Foundation

struct MessageDisplayFormatter {
    static func rolePlayText(
        for message: MessageModel,
        characterName: String,
        userName: String = "Devon"
    ) -> String {
        var processedText = message.text
        processedText = processedText.replacingOccurrences(
            of: "\"([^\"]+)\"",
            with: "`\"$1\"`",
            options: .regularExpression
        )
        processedText = processedText.replacingOccurrences(
            of: "\u{201C}([^\u{201D}]+)\u{201D}",
            with: "`\u{201C}$1\u{201D}`",
            options: .regularExpression
        )
        processedText = processedText.replacingOccurrences(of: "{{char}}", with: characterName)
        processedText = processedText.replacingOccurrences(of: "{{user}}", with: userName)
        return processedText
    }
}

