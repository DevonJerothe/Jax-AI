import Foundation
import UIKit

extension String {
    func decodeStringArray() throws -> [String] {
        guard let data = data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([String].self, from: data)
    }

    // Decode the escaped text users type in settings into the stored runtime value.
    func decodeEscapedSequence() -> String {
        guard self.isEmpty == false else {
            return ""
        }

        var decoded = "" 
        var isEscaping = false 

        for character in self {
            if isEscaping {
                switch character {
                case "n":
                    decoded.append("\n")
                case "t":
                    decoded.append("\t")
                case "r":
                    decoded.append("\r")
                case "\\":
                    decoded.append("\\")
                default:
                    decoded.append("\\")
                    decoded.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                decoded.append(character)
            }
        }

        if isEscaping {
            decoded.append("\\")
        }

        return decoded
    }

    func encodeEscapedSequence() -> String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}

extension Array where Element == String {
    func encodeStringArray() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
