import Foundation
import Supabase

/// All network I/O + DTO<->domain mapping lives here so AppStore stays
/// focused on app state. Every function that touches a table relying on a
/// "party to this row" RLS policy (offers, group_offers,
/// group_offer_members, proposals, notifications, schedule_entries) can
/// select without an extra filter — RLS already scopes the result set to
/// rows the signed-in user is allowed to see (see drinkmatch-backend's
/// supabase/migrations/20260801000007_rls.sql).
enum SupabaseRepository {
    private static var client: SupabaseClient { SupabaseManager.client }

    // MARK: - Auth

    static func signInWithApple(idToken: String) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken))
        return session.user.id
    }

    static func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Deletes the caller's auth.users row server-side, which cascades
    /// through every table via public.users.id's own cascade (see
    /// drinkmatch-backend's 20260801000014_account_deletion.sql). The local
    /// session is still valid afterward until it's cleared — callers should
    /// follow this with signOut().
    static func deleteAccount() async throws {
        _ = try await client.rpc("delete_own_account").execute()
    }

    // MARK: - Profile

    static func fetchProfile(userID: UUID) async throws -> UserRow? {
        let rows: [UserRow] = try await client.from("users")
            .select("id,role,airline,base_airport,years_of_service,full_name,note,display_mode,nickname,verification_method,is_subscribed")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func createProfile(_ params: CreateProfileParams) async throws -> UserRow {
        try await client.rpc("create_profile", params: params).execute().value
    }

    static func updateRole(userID: UUID, role: String) async throws {
        struct Patch: Encodable { var role: String }
        _ = try await client.from("users").update(Patch(role: role)).eq("id", value: userID).execute()
    }

    static func updateDisplayPreference(userID: UUID, displayMode: DisplayMode, nickname: String) async throws {
        struct Patch: Encodable {
            var displayMode: String
            var nickname: String?
            enum CodingKeys: String, CodingKey { case displayMode = "display_mode", nickname }
        }
        let patch = Patch(displayMode: displayMode.rawValue, nickname: nickname.isEmpty ? nil : nickname)
        _ = try await client.from("users").update(patch).eq("id", value: userID).execute()
    }

    // MARK: - Schedule

    static func fetchSchedule(userID: UUID) async throws -> [ScheduleEntryRow] {
        try await client.from("schedule_entries")
            .select("id,day,airport_code,available_from")
            .eq("user_id", value: userID)
            .order("day", ascending: true)
            .execute()
            .value
    }

    static func fetchHiddenFrom(entryIDs: [UUID]) async throws -> [UUID: [UUID]] {
        guard !entryIDs.isEmpty else { return [:] }
        struct Row: Decodable {
            var scheduleEntryId: UUID
            var hiddenFromUserId: UUID
            enum CodingKeys: String, CodingKey {
                case scheduleEntryId = "schedule_entry_id"
                case hiddenFromUserId = "hidden_from_user_id"
            }
        }
        let rows: [Row] = try await client.from("schedule_visibility_exceptions")
            .select("schedule_entry_id,hidden_from_user_id")
            .in("schedule_entry_id", values: entryIDs)
            .execute()
            .value
        return Dictionary(grouping: rows, by: \.scheduleEntryId).mapValues { $0.map(\.hiddenFromUserId) }
    }

    /// Upserts one day's entry (unique on `user_id, day`) and replaces its
    /// hidden-from set, returning the row's id for further edits.
    @discardableResult
    static func upsertScheduleEntry(userID: UUID, day: Int, location: String, from: String, hiddenFrom: [UUID]) async throws -> UUID {
        let payload = ScheduleEntryInsert(
            userId: userID,
            day: postgresDateString(forDay: day),
            airportCode: location,
            availableFrom: postgresTimeString(fromClientTime: from)
        )
        let row: ScheduleEntryRow = try await client.from("schedule_entries")
            .upsert(payload, onConflict: "user_id,day")
            .select("id,day,airport_code,available_from")
            .single()
            .execute()
            .value

        _ = try await client.from("schedule_visibility_exceptions")
            .delete()
            .eq("schedule_entry_id", value: row.id)
            .execute()
        if !hiddenFrom.isEmpty {
            let inserts = hiddenFrom.map { VisibilityExceptionInsert(scheduleEntryId: row.id, hiddenFromUserId: $0) }
            _ = try await client.from("schedule_visibility_exceptions").insert(inserts).execute()
        }
        return row.id
    }

    static func deleteScheduleEntry(id: UUID) async throws {
        _ = try await client.from("schedule_entries").delete().eq("id", value: id).execute()
    }

    // MARK: - Verification / referral codes

    static func verifyEmailDomain(email: String) async throws -> Bool {
        try await client.rpc("verify_email_domain", params: EmailParams(email: email)).execute().value
    }

    static func issueReferralCode() async throws -> String {
        try await client.rpc("issue_referral_code").execute().value
    }

    static func redeemReferralCode(code: String) async throws {
        _ = try await client.rpc("redeem_referral_code", params: CodeParams(code: code)).execute()
    }

    static func fetchMyReferralCodes(userID: UUID) async throws -> [(code: String, used: Bool)] {
        struct Row: Decodable { var code: String; var used: Bool }
        let rows: [Row] = try await client.from("referral_codes")
            .select("code,used")
            .eq("issued_by_user_id", value: userID)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { (code: $0.code, used: $0.used) }
    }

    // MARK: - Friends

    static func issueInviteCode() async throws -> String {
        try await client.rpc("issue_invite_code").execute().value
    }

    static func redeemInviteCode(code: String) async throws {
        _ = try await client.rpc("redeem_invite_code", params: CodeParams(code: code)).execute()
    }

    static func fetchFriendsWithOverlap() async throws -> [FriendOverlapRow] {
        try await client.rpc("list_friends_with_overlap").execute().value
    }

    static func fetchMyInviteCodes(userID: UUID) async throws -> [(code: String, used: Bool)] {
        struct Row: Decodable { var code: String; var used: Bool }
        let rows: [Row] = try await client.from("invite_codes")
            .select("code,used")
            .eq("owner_user_id", value: userID)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { (code: $0.code, used: $0.used) }
    }

    // MARK: - Strangers

    static func searchStrangerCandidates(baseAirport: String?, role: String?) async throws -> [StrangerCandidateRow] {
        let params = StrangerSearchParams(
            baseAirport: (baseAirport == "ALL" ? nil : baseAirport),
            role: (role == "ALL" ? nil : role)
        )
        return try await client.rpc("search_stranger_candidates", params: params).execute().value
    }

    static func passCandidate(userID: UUID, candidateID: UUID) async throws {
        _ = try await client.from("passed_candidates")
            .insert(PassedCandidateInsert(userId: userID, candidateUserId: candidateID))
            .execute()
    }

    // MARK: - Overlap

    static func fetchOverlap(otherUserID: UUID) async throws -> [StayOverlap] {
        let rows: [MatchOverlapRow] = try await client.rpc("get_match_overlap", params: OtherUserParams(otherUserId: otherUserID))
            .execute()
            .value
        return rows.compactMap { row in
            guard let day = dayOfMonth(fromPostgresDate: row.day) else { return nil }
            return StayOverlap(
                day: day,
                location: row.airportCode,
                myFrom: clientTimeString(fromPostgresTime: row.myAvailableFrom),
                otherFrom: clientTimeString(fromPostgresTime: row.theirAvailableFrom)
            )
        }
    }

    // MARK: - Offers

    static func fetchMyOffers() async throws -> [OfferRow] {
        try await client.from("offers")
            .select("id,from_user_id,to_user_id,day,airport_code,auto_accept,status")
            .execute()
            .value
    }

    static func createOffer(toUserID: UUID, day: Int, location: String, autoAccept: Bool) async throws -> UUID {
        let params = CreateOfferParams(toUserId: toUserID, day: postgresDateString(forDay: day), airportCode: location, autoAccept: autoAccept)
        return try await client.rpc("create_offer", params: params).execute().value
    }

    static func acceptOffer(offerID: UUID) async throws {
        _ = try await client.rpc("accept_offer", params: OfferIDParams(offerId: offerID)).execute()
    }

    static func fetchOfferCounterpart(offerID: UUID) async throws -> OfferCounterpartRow? {
        let rows: [OfferCounterpartRow] = try await client.rpc("get_offer_counterpart", params: OfferIDParams(offerId: offerID)).execute().value
        return rows.first
    }

    /// The matched partner's stay calendar for an accepted offer (the green
    /// tappable days in the client's ReadOnlyStayCalendar) — only callable
    /// once accepted, and already excludes days the partner hid from us.
    static func fetchMatchCalendar(offerID: UUID) async throws -> [ScheduleEntryRow] {
        try await client.rpc("get_match_calendar", params: OfferIDParams(offerId: offerID)).execute().value
    }

    // MARK: - Group offers

    static func fetchMyGroups() async throws -> [GroupOfferRow] {
        try await client.from("group_offers")
            .select("id,day,airport_code,created_by_user_id")
            .execute()
            .value
    }

    static func createGroupOffer(day: Int, location: String, memberIDs: [UUID], autoAccept: Bool) async throws -> UUID {
        let params = CreateGroupOfferParams(day: postgresDateString(forDay: day), airportCode: location, memberIds: memberIDs, autoAccept: autoAccept)
        return try await client.rpc("create_group_offer", params: params).execute().value
    }

    static func acceptGroupOfferMembership(groupOfferID: UUID) async throws {
        _ = try await client.rpc("accept_group_offer_membership", params: GroupOfferIDParams(groupOfferId: groupOfferID)).execute()
    }

    static func fetchGroupMembersInfo(groupOfferID: UUID) async throws -> [GroupMemberInfoRow] {
        try await client.rpc("get_group_offer_members_info", params: GroupOfferIDParams(groupOfferId: groupOfferID)).execute().value
    }

    // MARK: - Proposals

    static func sendProposal(day: Int, location: String, time: String, place: String, offerID: UUID?, groupOfferID: UUID?) async throws -> UUID {
        let params = SendProposalParams(
            day: postgresDateString(forDay: day),
            airportCode: location,
            meetingTime: postgresTimeString(fromClientTime: time),
            place: place.isEmpty ? nil : place,
            offerId: offerID,
            groupOfferId: groupOfferID
        )
        return try await client.rpc("send_proposal", params: params).execute().value
    }

    static func fetchProposal(offerID: UUID) async throws -> ProposalRow? {
        let rows: [ProposalRow] = try await client.from("proposals")
            .select("id,offer_id,group_offer_id,day,airport_code,meeting_time,place")
            .eq("offer_id", value: offerID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func fetchProposal(groupOfferID: UUID) async throws -> ProposalRow? {
        let rows: [ProposalRow] = try await client.from("proposals")
            .select("id,offer_id,group_offer_id,day,airport_code,meeting_time,place")
            .eq("group_offer_id", value: groupOfferID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Billing

    /// Calls drinkmatch-backend's verify-purchase Edge Function right after
    /// a local StoreKit 2 purchase, so the caller unlocks stranger-matching
    /// immediately instead of waiting on Apple's async server notification.
    static func verifyPurchase(transactionJWS: String) async throws {
        try await client.functions.invoke(
            "verify-purchase",
            options: FunctionInvokeOptions(body: VerifyPurchaseBody(transactionJWS: transactionJWS))
        )
    }

    // MARK: - Report / block

    static func blockUser(userID: UUID) async throws {
        _ = try await client.rpc("block_user", params: BlockUserParams(userId: userID)).execute()
    }

    static func unblockUser(userID: UUID) async throws {
        _ = try await client.rpc("unblock_user", params: BlockUserParams(userId: userID)).execute()
    }

    static func fetchBlockedUsers() async throws -> [BlockedUserRow] {
        try await client.rpc("list_blocked_users").execute().value
    }

    @discardableResult
    static func submitReport(reportedUserID: UUID, reason: ReportReason, details: String?, offerID: UUID?, groupOfferID: UUID?) async throws -> UUID {
        let params = SubmitReportParams(
            reportedUserId: reportedUserID,
            reason: reason.rawValue,
            details: details,
            offerId: offerID,
            groupOfferId: groupOfferID
        )
        return try await client.rpc("submit_report", params: params).execute().value
    }

    // MARK: - Notifications

    static func fetchNotifications() async throws -> [NotificationRow] {
        try await client.from("notifications")
            .select("id,type,body,read")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func markAllNotificationsRead(userID: UUID) async throws {
        _ = try await client.from("notifications")
            .update(ReadFlagUpdate(read: true))
            .eq("user_id", value: userID)
            .eq("read", value: false)
            .execute()
    }
}
