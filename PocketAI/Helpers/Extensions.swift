import Foundation 

extension String {
    func decodeStringArray() throws -> [String] {
        guard let data = data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([String].self, from: data)
    }
}

extension Array where Element == String {
    func encodeStringArray() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}