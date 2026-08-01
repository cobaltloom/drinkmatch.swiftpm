import Foundation

/// The schedule board is scoped to a single demo month, mirroring the
/// original prototype so the bundled sample schedules line up with real
/// calendar cells.
enum BoardCalendar {
    static let year = 2026
    static let month = 7 // July (1-indexed)

    static var daysInMonth: Int {
        let components = DateComponents(year: year, month: month, day: 1)
        let calendar = Calendar(identifier: .gregorian)
        return calendar.range(of: .day, in: .month, for: calendar.date(from: components)!)!.count
    }

    /// Number of leading blank cells before day 1, with Sunday as the first column.
    static var leadingBlankCount: Int {
        let components = DateComponents(year: year, month: month, day: 1)
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: calendar.date(from: components)!) // 1 = Sunday
        return weekday - 1
    }

    static let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]
}

func dateLabel(_ day: Int) -> String {
    "\(BoardCalendar.month)/\(day)"
}

func airportName(_ code: String) -> String {
    StayAirports.all.first { $0.code == code }?.name ?? code
}

func airportLabel(_ code: String) -> String {
    "\(code) (\(airportName(code)))"
}

func initials(from fullName: String) -> String {
    let parts = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .map(String.init)
        .filter { !$0.isEmpty }
    guard !parts.isEmpty else { return "" }
    return parts.map { String($0.prefix(1)).uppercased() }.joined(separator: ".") + "."
}

/// The later (i.e. more restrictive / safer) of two "available from" times,
/// compared lexicographically since both are zero-padded "HH:mm" strings.
func laterTime(_ first: String, _ second: String) -> String {
    first > second ? first : second
}

// MARK: - "HH:mm" <-> Date, for binding a DatePicker to a stored time string.

func timeString(from date: Date) -> String {
    let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
}

func date(fromTimeString hhmm: String) -> Date {
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    var comps = DateComponents(year: BoardCalendar.year, month: BoardCalendar.month, day: 1)
    comps.hour = parts.first ?? 19
    comps.minute = parts.count > 1 ? parts[1] : 0
    return Calendar.current.date(from: comps) ?? Date()
}
