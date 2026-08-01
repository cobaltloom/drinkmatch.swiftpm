import Foundation

/// The Supabase Swift client's default JSON encoder/decoder do NOT convert
/// between camelCase and snake_case (verified against postgrest-swift's
/// source), so every DTO below spells out CodingKeys explicitly rather than
/// relying on automatic conversion. Their dateDecodingStrategy is also a
/// custom full-ISO8601 parser, which does not accept PostgREST's plain
/// `date` ("2026-08-06") or `time` ("19:00:00") string formats — so those
/// columns are modeled as `String` here, not `Date`, and converted at the
/// boundary using the helpers below.

/// The client's schedule UI works in day-of-month integers scoped to
/// `BoardCalendar.year`/`BoardCalendar.month` (see Data/Matching.swift);
/// the backend stores a full SQL `date`. These convert between the two.
func postgresDateString(forDay day: Int) -> String {
    String(format: "%04d-%02d-%02d", BoardCalendar.year, BoardCalendar.month, day)
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

/// Error codes raised via `raise exception '...' using errcode = 'P0001'`
/// in the backend's PL/pgSQL functions (see drinkmatch-backend's
/// supabase/migrations/20260801000008_functions.sql). PostgREST surfaces
/// the exception message as the error's `message`/`details` — this matches
/// against that string so the UI can route to the right screen/copy instead
/// of showing a raw database error.
enum BackendErrorCode: String {
    case notAuthenticated = "not_authenticated"
    case verificationRequired = "verification_required"
    case subscriptionRequired = "subscription_required"
    case noScheduleOverlap = "no_schedule_overlap"
    case referralCodeCapReached = "referral_code_cap_reached"
    case referralCodeNotFound = "referral_code_not_found"
    case referralCodeAlreadyUsed = "referral_code_already_used"
    case referralCodeSelfUse = "referral_code_self_use"
    case inviteCodeNotFound = "invite_code_not_found"
    case inviteCodeAlreadyUsed = "invite_code_already_used"
    case inviteCodeSelfUse = "invite_code_self_use"
    case offerNotFound = "offer_not_found"
    case offerNotPending = "offer_not_pending"
    case offerNotAccepted = "offer_not_accepted"
    case notAuthorized = "not_authorized"
    case cannotOfferSelf = "cannot_offer_self"

    /// Best-effort match against a thrown error's description — the
    /// PostgrestError message contains the RAISE EXCEPTION text verbatim.
    static func from(_ error: Error) -> BackendErrorCode? {
        let text = String(describing: error)
        return allCases.first { text.contains($0.rawValue) }
    }

    static let allCases: [BackendErrorCode] = [
        .notAuthenticated, .verificationRequired, .subscriptionRequired, .noScheduleOverlap,
        .referralCodeCapReached, .referralCodeNotFound, .referralCodeAlreadyUsed, .referralCodeSelfUse,
        .inviteCodeNotFound, .inviteCodeAlreadyUsed, .inviteCodeSelfUse,
        .offerNotFound, .offerNotPending, .offerNotAccepted, .notAuthorized, .cannotOfferSelf,
    ]
}
