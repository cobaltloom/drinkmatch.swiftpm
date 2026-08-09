import Foundation

// MARK: - RPC parameter payloads
//
// Property names use explicit CodingKeys matching the backend's `p_`-
// prefixed argument names exactly (drinkmatch-backend's
// supabase/migrations/20260801000008_functions.sql) — plain JSONEncoder
// does no camelCase<->snake_case conversion, and PostgREST calls Postgres
// functions using these exact names as named parameters.

struct CreateProfileParams: Encodable {
    var role: String
    var baseAirport: String
    var fullName: String
    var ageConfirmed: Bool
    var airline: String?
    var yearsOfService: Int?
    var note: String?
    var displayMode: String
    var nickname: String?

    enum CodingKeys: String, CodingKey {
        case role = "p_role"
        case baseAirport = "p_base_airport"
        case fullName = "p_full_name"
        case ageConfirmed = "p_age_confirmed"
        case airline = "p_airline"
        case yearsOfService = "p_years_of_service"
        case note = "p_note"
        case displayMode = "p_display_mode"
        case nickname = "p_nickname"
    }
}

struct EmailParams: Encodable {
    var email: String
    enum CodingKeys: String, CodingKey { case email = "p_email" }
}

struct CodeParams: Encodable {
    var code: String
    enum CodingKeys: String, CodingKey { case code = "p_code" }
}

struct OtherUserParams: Encodable {
    var otherUserId: UUID
    enum CodingKeys: String, CodingKey { case otherUserId = "p_other_user_id" }
}

struct StrangerSearchParams: Encodable {
    var baseAirport: String?
    var role: String?
    enum CodingKeys: String, CodingKey {
        case baseAirport = "p_base_airport"
        case role = "p_role"
    }
}

struct OfferIDParams: Encodable {
    var offerId: UUID
    enum CodingKeys: String, CodingKey { case offerId = "p_offer_id" }
}

struct GroupOfferIDParams: Encodable {
    var groupOfferId: UUID
    enum CodingKeys: String, CodingKey { case groupOfferId = "p_group_offer_id" }
}

struct CreateOfferParams: Encodable {
    var toUserId: UUID
    var day: String
    var airportCode: String
    var autoAccept: Bool
    enum CodingKeys: String, CodingKey {
        case toUserId = "p_to_user_id"
        case day = "p_day"
        case airportCode = "p_airport_code"
        case autoAccept = "p_auto_accept"
    }
}

struct CreateGroupOfferParams: Encodable {
    var day: String
    var airportCode: String
    var memberIds: [UUID]
    var autoAccept: Bool
    enum CodingKeys: String, CodingKey {
        case day = "p_day"
        case airportCode = "p_airport_code"
        case memberIds = "p_member_ids"
        case autoAccept = "p_auto_accept"
    }
}

struct BlockUserParams: Encodable {
    var userId: UUID
    enum CodingKeys: String, CodingKey { case userId = "p_user_id" }
}

struct SubmitReportParams: Encodable {
    var reportedUserId: UUID
    var reason: String
    var details: String?
    var offerId: UUID?
    var groupOfferId: UUID?
    enum CodingKeys: String, CodingKey {
        case reportedUserId = "p_reported_user_id"
        case reason = "p_reason"
        case details = "p_details"
        case offerId = "p_offer_id"
        case groupOfferId = "p_group_offer_id"
    }
}

struct SendProposalParams: Encodable {
    var day: String
    var airportCode: String
    var meetingTime: String
    var place: String?
    var offerId: UUID?
    var groupOfferId: UUID?
    enum CodingKeys: String, CodingKey {
        case day = "p_day"
        case airportCode = "p_airport_code"
        case meetingTime = "p_meeting_time"
        case place = "p_place"
        case offerId = "p_offer_id"
        case groupOfferId = "p_group_offer_id"
    }
}

// MARK: - Edge Function payloads
//
// Unlike the RPC params above, these bodies go to our own Edge Functions
// (drinkmatch-backend's supabase/functions/), not PostgREST — there's no
// `p_`-prefixed snake_case convention to match, so property names are
// whatever the corresponding index.ts reads.

struct VerifyPurchaseBody: Encodable {
    var transactionJWS: String
}

// MARK: - Row payloads
//
// Each only declares the columns the client actually reads — call sites use
// an explicit `.select("col1,col2,...")` matching these field sets, rather
// than `.select("*")`, so there's no risk from columns (timestamps, etc.)
// this DTO doesn't model.

struct UserRow: Decodable {
    var id: UUID
    var role: String
    var airline: String?
    var baseAirport: String
    var yearsOfService: Int?
    var fullName: String
    var note: String?
    var displayMode: DisplayMode
    var nickname: String?
    var verificationMethod: String?
    var isSubscribed: Bool

    enum CodingKeys: String, CodingKey {
        case id, role, airline, note, nickname
        case baseAirport = "base_airport"
        case yearsOfService = "years_of_service"
        case fullName = "full_name"
        case displayMode = "display_mode"
        case verificationMethod = "verification_method"
        case isSubscribed = "is_subscribed"
    }

    var isVerified: Bool { verificationMethod != nil }

    var asUserProfile: UserProfile {
        UserProfile(role: role, base: baseAirport, fullName: fullName, displayMode: displayMode, nickname: nickname ?? "", airline: airline ?? "")
    }

    var asPerson: Person {
        Person(id: id, name: fullName, fullName: fullName, role: role, airline: airline ?? "",
               base: baseAirport, years: yearsOfService ?? 0, note: note ?? "", stays: [])
    }
}

struct ScheduleEntryRow: Decodable {
    var id: UUID
    var day: String
    var airportCode: String
    var availableFrom: String
    var visibleToStrangers: Bool

    enum CodingKeys: String, CodingKey {
        case id, day
        case airportCode = "airport_code"
        case availableFrom = "available_from"
        case visibleToStrangers = "visible_to_strangers"
    }

    var asStayEntry: StayEntry? {
        guard let dayOfMonth = dayOfMonth(fromPostgresDate: day) else { return nil }
        return StayEntry(day: dayOfMonth, location: airportCode, from: clientTimeString(fromPostgresTime: availableFrom), visibleToStrangers: visibleToStrangers)
    }
}

struct MatchOverlapRow: Decodable {
    var day: String
    var airportCode: String
    var myAvailableFrom: String
    var theirAvailableFrom: String

    enum CodingKeys: String, CodingKey {
        case day
        case airportCode = "airport_code"
        case myAvailableFrom = "my_available_from"
        case theirAvailableFrom = "their_available_from"
    }
}

struct FriendOverlapRow: Decodable, Identifiable {
    var friendId: UUID
    var role: String
    var airline: String?
    var baseAirport: String
    var note: String?
    var fullName: String
    var overlapDays: Int

    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
        case role, airline, note
        case baseAirport = "base_airport"
        case fullName = "full_name"
        case overlapDays = "overlap_days"
    }

    var id: UUID { friendId }

    var asPerson: Person {
        Person(id: friendId, name: fullName, fullName: fullName, role: role, airline: airline ?? "",
               base: baseAirport, years: 0, note: note ?? "", stays: [])
    }
}

struct StrangerCandidateRow: Decodable, Identifiable {
    var candidateId: UUID
    var role: String
    var airline: String?
    var baseAirport: String
    var note: String?
    var displayName: String
    var overlapDays: Int

    enum CodingKeys: String, CodingKey {
        case candidateId = "candidate_id"
        case role, airline, note
        case baseAirport = "base_airport"
        case displayName = "display_name"
        case overlapDays = "overlap_days"
    }

    var id: UUID { candidateId }

    var asPerson: Person {
        Person(id: candidateId, name: displayName, fullName: nil, role: role, airline: airline ?? "",
               base: baseAirport, years: 0, note: note ?? "", stays: [])
    }
}

struct OfferRow: Decodable, Identifiable {
    var id: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var day: String
    var airportCode: String
    var autoAccept: Bool
    var status: OfferStatus

    enum CodingKeys: String, CodingKey {
        case id, day, status
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case airportCode = "airport_code"
        case autoAccept = "auto_accept"
    }
}

struct GroupOfferRow: Decodable, Identifiable {
    var id: UUID
    var day: String
    var airportCode: String
    var createdByUserId: UUID

    enum CodingKeys: String, CodingKey {
        case id, day
        case airportCode = "airport_code"
        case createdByUserId = "created_by_user_id"
    }
}

struct GroupMemberInfoRow: Decodable, Identifiable {
    var userId: UUID
    var role: String
    var airline: String?
    var baseAirport: String
    var note: String?
    var yearsOfService: Int?
    var displayName: String
    var status: OfferStatus

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role, airline, note, status
        case baseAirport = "base_airport"
        case yearsOfService = "years_of_service"
        case displayName = "display_name"
    }

    var id: UUID { userId }

    /// `displayName` is set as both `name` and `fullName` here (rather than
    /// leaving `fullName` nil) because the server already resolved the
    /// friend-vs-stranger name choice via `display_name_for` — the view
    /// doesn't need to re-derive it, so `displayName(showFullName:)`
    /// returns the same correct value regardless of which flag is passed.
    var asPerson: Person {
        Person(id: userId, name: displayName, fullName: displayName, role: role, airline: airline ?? "",
               base: baseAirport, years: yearsOfService ?? 0, note: note ?? "", stays: [])
    }
}

struct OfferCounterpartRow: Decodable {
    var userId: UUID
    var role: String
    var airline: String?
    var baseAirport: String
    var note: String?
    var yearsOfService: Int?
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role, airline, note
        case baseAirport = "base_airport"
        case yearsOfService = "years_of_service"
        case displayName = "display_name"
    }

    /// See the identical note on GroupMemberInfoRow.asPerson.
    var asPerson: Person {
        Person(id: userId, name: displayName, fullName: displayName, role: role, airline: airline ?? "",
               base: baseAirport, years: yearsOfService ?? 0, note: note ?? "", stays: [])
    }
}

struct ProposalRow: Decodable {
    var id: UUID
    var offerId: UUID?
    var groupOfferId: UUID?
    var day: String
    var airportCode: String
    var meetingTime: String
    var place: String?

    enum CodingKeys: String, CodingKey {
        case id, day, place
        case offerId = "offer_id"
        case groupOfferId = "group_offer_id"
        case airportCode = "airport_code"
        case meetingTime = "meeting_time"
    }

    var asProposal: Proposal? {
        guard let dayOfMonth = dayOfMonth(fromPostgresDate: day) else { return nil }
        return Proposal(day: dayOfMonth, location: airportCode, time: clientTimeString(fromPostgresTime: meetingTime), place: place ?? "")
    }
}

struct BlockedUserRow: Decodable {
    var userId: UUID
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
    }

    var asBlockedUser: BlockedUser { BlockedUser(userID: userId, displayName: displayName) }
}

struct NotificationRow: Decodable, Identifiable {
    var id: UUID
    var type: String
    var body: String
    var read: Bool

    var asAppNotification: AppNotification {
        AppNotification(id: id.uuidString, body: body, read: read)
    }
}

// MARK: - Insert payloads

struct ScheduleEntryInsert: Encodable {
    var userId: UUID
    var day: String
    var airportCode: String
    var availableFrom: String
    var visibleToStrangers: Bool
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case day
        case airportCode = "airport_code"
        case availableFrom = "available_from"
        case visibleToStrangers = "visible_to_strangers"
    }
}

struct VisibilityExceptionInsert: Encodable {
    var scheduleEntryId: UUID
    var hiddenFromUserId: UUID
    enum CodingKeys: String, CodingKey {
        case scheduleEntryId = "schedule_entry_id"
        case hiddenFromUserId = "hidden_from_user_id"
    }
}

struct PassedCandidateInsert: Encodable {
    var userId: UUID
    var candidateUserId: UUID
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case candidateUserId = "candidate_user_id"
    }
}

struct PushTokenInsert: Encodable {
    var userId: UUID
    var platform: String
    var token: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case platform, token
    }
}

// MARK: - Update payloads

struct ReadFlagUpdate: Encodable {
    var read: Bool
}
