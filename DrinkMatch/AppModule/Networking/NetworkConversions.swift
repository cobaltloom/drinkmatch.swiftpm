import Foundation

/// PostgREST speaks the database's actual snake_case column/RPC-parameter
/// names on the wire, so every DTO in DTOs.swift spells out CodingKeys
/// explicitly rather than relying on automatic camelCase conversion (Swift's
/// JSONDecoder has no such conversion built in either way). RestClient's
/// plain JSONDecoder also has no special date-decoding strategy, which
/// doesn't accept PostgREST's plain `date` ("2026-08-06") or `time`
/// ("19:00:00") string formats — so those columns are modeled as `String`
/// here, not `Date`, and converted at the boundary using the helpers below.

/// The client's schedule UI works in day-of-month integers scoped to
/// `BoardCalendar.year`/`BoardCalendar.month` (see Data/CalendarFormatting.swift);
/// the backend stores a full SQL `date`. These convert between the two.
func postgresDateString(forDay day: Int) -> String {
    postgresDateString(year: BoardCalendar.year, month: BoardCalendar.month, forDay: day)
}

/// Same as `postgresDateString(forDay:)`, but for callers juggling a
/// specific navigated month instead of the app-wide default — currently
/// just the schedule editor (see `ScheduleSetupView`).
func postgresDateString(year: Int, month: Int, forDay day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, month, day)
}

func dayOfMonth(fromPostgresDate iso: String) -> Int? {
    let parts = iso.split(separator: "-")
    guard parts.count == 3, let day = Int(parts[2]) else { return nil }
    return day
}

/// The client stores "HH:mm"; Postgres `time` round-trips as "HH:mm:ss".
func postgresTimeString(fromClientTime hhmm: String) -> String {
    hhmm.count == 5 ? hhmm + ":00" : hhmm
}

func clientTimeString(fromPostgresTime hhmmss: String) -> String {
    String(hhmmss.prefix(5))
}

/// Optional-friendly counterparts, for the nullable `available_until` /
/// `until` fields (an overnight stay's next-day cutoff) — nil in, nil out.
func postgresTimeString(fromClientTime hhmm: String?) -> String? {
    hhmm.map { postgresTimeString(fromClientTime: $0) }
}

func clientTimeString(fromPostgresTime hhmmss: String?) -> String? {
    hhmmss.map { clientTimeString(fromPostgresTime: $0) }
}

/// Postgres `timestamptz` round-trips as e.g. "2026-08-16T12:34:56.789012+00:00"
/// — sub-second precision this app never needs, and `ISO8601DateFormatter`
/// disagrees across platforms on how many fractional digits to accept, so
/// it's stripped before parsing rather than relying on `.withFractionalSeconds`.
func date(fromPostgresTimestamp iso: String) -> Date? {
    var stripped = iso
    if let dotIndex = iso.firstIndex(of: "."),
       let offsetStart = iso[iso.index(after: dotIndex)...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
        stripped = String(iso[..<dotIndex]) + iso[offsetStart...]
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: stripped)
}
