import Foundation

struct MessageDisplayFormatter {
    static func rolePlayText(
        for message: MessageModel,
        characterName: String,
        userName: String = "{{user}}"
    ) -> String {
        var processedText = message.text
        processedText = processedText.replacingOccurrences(of: "{{char}}", with: characterName)
        processedText = processedText.replacingOccurrences(of: "{{user}}", with: userName)
        return processedText
    }
}

