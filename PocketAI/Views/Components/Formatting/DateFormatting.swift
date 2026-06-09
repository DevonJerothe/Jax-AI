import Foundation

enum AppDateFormatting {
    static func thumbnailTimestamp(fromISO8601 stringDate: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: stringDate) else {
            return ""
        }

        return thumbnailTimestamp(from: date)
    }

    static func thumbnailTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day, daysAgo <= 7 {
            formatter.dateFormat = "EEE"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: date)
    }

    static func chatListTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEE"
        }

        return formatter.string(from: date)
    }
}
