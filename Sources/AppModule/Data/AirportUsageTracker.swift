import Foundation

/// Tracks how many times each airport code has been picked as a stay
/// location, so `AirportAutocompleteField` can surface frequently-used ones
/// first. Persisted locally per-device (`UserDefaults`) — this is a personal
/// convenience ranking, not something that needs to sync across devices or
/// live server-side.
enum AirportUsageTracker {
    private static let defaultsKey = "airportUsageCounts"

    private static var counts: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static func recordUse(_ code: String) {
        var current = counts
        current[code, default: 0] += 1
        counts = current
    }

    static func count(for code: String) -> Int {
        counts[code] ?? 0
    }
}
