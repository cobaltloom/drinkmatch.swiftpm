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
    var birthYear: Int?

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
        case birthYear = "p_birth_year"
    }
}

struct UpdateIdentityParams: Encodable {
    var role: String
    var airline: String?
    var baseAirport: String

    enum CodingKeys: String, CodingKey {
        case role = "p_role"
        case airline = "p_airline"
        case baseAirport = "p_base_airport"
    }
}

struct UpdateBirthYearParams: Encodable {
    var birthYear: Int?
    enum CodingKeys: String, CodingKey { case birthYear = "p_birth_year" }
}

struct RequestFriendParams: Encodable {
    var code: String
    enum CodingKeys: String, CodingKey { case code = "p_code" }
}

struct RespondFriendRequestParams: Encodable {
    var requestId: UUID
    var accept: Bool
    enum CodingKeys: String, CodingKey {
        case requestId = "p_request_id"
        case accept = "p_accept"
    }
}

struct EmailParams: Encodable {
    var email: String
    enum CodingKeys: String, CodingKey { case email = "p_email" }
}

struct CreateMemberGroupParams: Encodable {
    var name: String
    enum CodingKeys: String, CodingKey { case name = "p_name" }
}

struct MemberGroupIDParams: Encodable {
    var groupId: UUID
    enum CodingKeys: String, CodingKey { case groupId = "p_group_id" }
}

struct InviteToMemberGroupParams: Encodable {
    var groupId: UUID
    var toUserId: UUID
    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
        case toUserId = "p_to_user_id"
    }
}

struct RespondMemberGroupInviteParams: Encodable {
    var inviteId: UUID
    var accept: Bool
    enum CodingKeys: String, CodingKey {
        case inviteId = "p_invite_id"
        case accept = "p_accept"
    }
}

struct MemberGroupCodeParams: Encodable {
    var code: String
    enum CodingKeys: String, CodingKey { case code = "p_code" }
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
    var birthYear: Int?
    var birthYearChangeCount: Int
    /// Postgres `timestamptz`, kept as a raw string like every other
    /// timestamp in this file (see NetworkConversions.swift's header
    /// comment) — converted to `Date` only at the `asUserProfile` boundary.
    var identityUpdatedAt: String
    var contactInfo: String?

    enum CodingKeys: String, CodingKey {
        case id, role, airline, note, nickname
        case baseAirport = "base_airport"
        case yearsOfService = "years_of_service"
        case fullName = "full_name"
        case displayMode = "display_mode"
        case verificationMethod = "verification_method"
        case isSubscribed = "is_subscribed"
        case birthYear = "birth_year"
        case birthYearChangeCount = "birth_year_change_count"
        case identityUpdatedAt = "identity_updated_at"
        case contactInfo = "contact_info"
    }

    var isVerified: Bool { verificationMethod != nil }

    var asUserProfile: UserProfile {
        UserProfile(
            role: role, base: baseAirport, fullName: fullName, displayMode: displayMode,
            nickname: nickname ?? "", airline: airline ?? "", birthYear: birthYear,
            birthYearChangeCount: birthYearChangeCount,
            // .distantPast on a parse failure means "no cooldown" rather than
            // wrongly locking editing forever — the server enforces the real
            // cooldown regardless of what the client shows.
            identityUpdatedAt: date(fromPostgresTimestamp: identityUpdatedAt) ?? .distantPast,
            contactInfo: contactInfo
        )
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
    var availableUntil: String?
    var visibleToStrangers: Bool

    enum CodingKeys: String, CodingKey {
        case id, day
        case airportCode = "airport_code"
        case availableFrom = "available_from"
        case availableUntil = "available_until"
        case visibleToStrangers = "visible_to_strangers"
    }

    var asStayEntry: StayEntry? {
        guard let dayOfMonth = dayOfMonth(fromPostgresDate: day) else { return nil }
        return StayEntry(
            day: dayOfMonth, location: airportCode, from: clientTimeString(fromPostgresTime: availableFrom),
            until: clientTimeString(fromPostgresTime: availableUntil), visibleToStrangers: visibleToStrangers
        )
    }
}

struct MatchOverlapRow: Decodable {
    var day: String
    var airportCode: String
    var myAvailableFrom: String
    var myAvailableUntil: String?
    var theirAvailableFrom: String
    var theirAvailableUntil: String?

    enum CodingKeys: String, CodingKey {
        case day
        case airportCode = "airport_code"
        case myAvailableFrom = "my_available_from"
        case myAvailableUntil = "my_available_until"
        case theirAvailableFrom = "their_available_from"
        case theirAvailableUntil = "their_available_until"
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

struct FriendRequestRow: Decodable, Identifiable {
    var requestId: UUID
    var fromUserId: UUID
    var fullName: String
    var role: String
    var airline: String?
    var baseAirport: String

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case fromUserId = "from_user_id"
        case fullName = "full_name"
        case role, airline
        case baseAirport = "base_airport"
    }

    var id: UUID { requestId }

    var asFriendRequest: FriendRequest {
        FriendRequest(id: requestId, fromUserID: fromUserId, fullName: fullName, role: role, airline: airline ?? "", base: baseAirport)
    }
}

struct MemberGroupRow: Decodable, Identifiable {
    var id: UUID
    var name: String
    var inviteCode: String
    var memberCount: Int
    var createdByUserId: UUID

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case memberCount = "member_count"
        case createdByUserId = "created_by_user_id"
    }

    var asMemberGroup: MemberGroup {
        MemberGroup(id: id, name: name, inviteCode: inviteCode, memberCount: memberCount, createdByUserID: createdByUserId)
    }
}

struct MemberGroupMemberRow: Decodable, Identifiable {
    var userId: UUID
    var fullName: String
    var role: String
    var airline: String?
    var baseAirport: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case role, airline
        case baseAirport = "base_airport"
    }

    var id: UUID { userId }

    var asMemberGroupPerson: MemberGroupPerson {
        MemberGroupPerson(userID: userId, fullName: fullName, role: role, airline: airline ?? "", base: baseAirport)
    }
}

struct MemberGroupInviteRow: Decodable, Identifiable {
    var inviteId: UUID
    var groupId: UUID
    var groupName: String
    var fromUserId: UUID
    var fromFullName: String
    var fromRole: String
    var fromAirline: String?
    var fromBaseAirport: String

    enum CodingKeys: String, CodingKey {
        case inviteId = "invite_id"
        case groupId = "group_id"
        case groupName = "group_name"
        case fromUserId = "from_user_id"
        case fromFullName = "from_full_name"
        case fromRole = "from_role"
        case fromAirline = "from_airline"
        case fromBaseAirport = "from_base_airport"
    }

    var id: UUID { inviteId }

    var asMemberGroupInvite: MemberGroupInvite {
        MemberGroupInvite(
            id: inviteId, groupID: groupId, groupName: groupName, fromUserID: fromUserId,
            fromFullName: fromFullName, fromRole: fromRole, fromAirline: fromAirline ?? "", fromBase: fromBaseAirport
        )
    }
}

/// Shared shape of create_member_group / join_member_group_via_code's
/// results — the latter just never populates inviteCode (the joiner
/// doesn't need it back).
struct MemberGroupSummaryRow: Decodable {
    var id: UUID
    var name: String
    var inviteCode: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
    }
}

struct MemberGroupScheduleRankingRow: Decodable {
    var day: String
    var airportCode: String
    var memberFullNames: [String]

    enum CodingKeys: String, CodingKey {
        case day
        case airportCode = "airport_code"
        case memberFullNames = "member_full_names"
    }

    var asMemberGroupScheduleMatch: MemberGroupScheduleMatch? {
        guard let dayOfMonth = dayOfMonth(fromPostgresDate: day) else { return nil }
        return MemberGroupScheduleMatch(day: dayOfMonth, location: airportCode, memberNames: memberFullNames)
    }
}

struct StrangerCandidateRow: Decodable, Identifiable {
    var candidateId: UUID
    var role: String
    var airline: String?
    var baseAirport: String
    var note: String?
    var displayName: String
    var birthYear: Int?
    var overlapDays: Int

    enum CodingKeys: String, CodingKey {
        case candidateId = "candidate_id"
        case role, airline, note
        case baseAirport = "base_airport"
        case displayName = "display_name"
        case birthYear = "birth_year"
        case overlapDays = "overlap_days"
    }

    var id: UUID { candidateId }

    var asPerson: Person {
        Person(id: candidateId, name: displayName, fullName: nil, role: role, airline: airline ?? "",
               base: baseAirport, years: 0, note: note ?? "", stays: [], birthYear: birthYear)
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
    var contactInfo: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role, airline, note, status
        case baseAirport = "base_airport"
        case yearsOfService = "years_of_service"
        case displayName = "display_name"
        case contactInfo = "contact_info"
    }

    var id: UUID { userId }

    /// `displayName` is set as both `name` and `fullName` here (rather than
    /// leaving `fullName` nil) because the server already resolved the
    /// friend-vs-stranger name choice via `display_name_for` — the view
    /// doesn't need to re-derive it, so `displayName(showFullName:)`
    /// returns the same correct value regardless of which flag is passed.
    var asPerson: Person {
        Person(id: userId, name: displayName, fullName: displayName, role: role, airline: airline ?? "",
               base: baseAirport, years: yearsOfService ?? 0, note: note ?? "", stays: [], contactInfo: contactInfo)
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
    var contactInfo: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role, airline, note
        case baseAirport = "base_airport"
        case yearsOfService = "years_of_service"
        case displayName = "display_name"
        case contactInfo = "contact_info"
    }

    /// See the identical note on GroupMemberInfoRow.asPerson.
    var asPerson: Person {
        Person(id: userId, name: displayName, fullName: displayName, role: role, airline: airline ?? "",
               base: baseAirport, years: yearsOfService ?? 0, note: note ?? "", stays: [], contactInfo: contactInfo)
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
    var availableUntil: String?
    var visibleToStrangers: Bool
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case day
        case airportCode = "airport_code"
        case availableFrom = "available_from"
        case availableUntil = "available_until"
        case visibleToStrangers = "visible_to_strangers"
    }

    // Swift's synthesized Encodable omits an Optional's key entirely when
    // nil (encodeIfPresent), which would leave a previously-set
    // available_until untouched by this upsert instead of clearing it when
    // the user removes the overnight cutoff. Encoding explicitly forces
    // JSON null onto the wire so PostgREST's UPDATE actually nulls it out.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(day, forKey: .day)
        try container.encode(airportCode, forKey: .airportCode)
        try container.encode(availableFrom, forKey: .availableFrom)
        try container.encode(availableUntil, forKey: .availableUntil)
        try container.encode(visibleToStrangers, forKey: .visibleToStrangers)
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
