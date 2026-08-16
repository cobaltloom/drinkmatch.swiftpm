import Foundation

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
    case cannotBlockSelf = "cannot_block_self"
    case cannotReportSelf = "cannot_report_self"
    case userBlocked = "user_blocked"
    case userNotFound = "user_not_found"
    case ageConfirmationRequired = "age_confirmation_required"
    case identityUpdateCooldown = "identity_update_cooldown"

    /// Best-effort match against a thrown error's description — RestClient's
    /// RequestError.description embeds PostgREST's JSON error body, which
    /// contains the RAISE EXCEPTION message text verbatim.
    static func from(_ error: Error) -> BackendErrorCode? {
        let text = String(describing: error)
        return allCases.first { text.contains($0.rawValue) }
    }

    static let allCases: [BackendErrorCode] = [
        .notAuthenticated, .verificationRequired, .subscriptionRequired, .noScheduleOverlap,
        .referralCodeCapReached, .referralCodeNotFound, .referralCodeAlreadyUsed, .referralCodeSelfUse,
        .inviteCodeNotFound, .inviteCodeAlreadyUsed, .inviteCodeSelfUse,
        .offerNotFound, .offerNotPending, .offerNotAccepted, .notAuthorized, .cannotOfferSelf,
        .cannotBlockSelf, .cannotReportSelf, .userBlocked, .userNotFound,
        .ageConfirmationRequired, .identityUpdateCooldown,
    ]
}
