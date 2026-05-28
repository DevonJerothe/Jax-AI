import Foundation
import SwiftTiktoken

// TokenCount cache
final class TokenCountCache {
    private var cache: [String: Int] = [:]

    func count(_ text: String, tokenizer: CoreBPE) -> Int {
        if let cached = cache[text] {
            return cached
        }

        let count = tokenizer.encodeWithSpecialTokens(text: text).count
        cache[text] = count
        return count
    }

    func clear() {
        cache.removeAll()
    }
}