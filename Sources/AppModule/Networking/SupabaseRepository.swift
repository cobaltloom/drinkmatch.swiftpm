import Foundation

/// All network I/O + DTO<->domain mapping lives here so DrinkMatchStore stays
/// focused on app state. Every function that touches a table relying on a
/// "party to this row" RLS policy (offers, group_offers,
/// group_offer_members, proposals, notifications, schedule_entries) can
/// select without an extra filter — RLS already scopes the result set to
/// rows the signed-in user is allowed to see (see drinkmatch-backend's
/// supabase/migrations/20260801000007_rls.sql).
///
/// Talks to Supabase's REST APIs directly via PostgREST.swift/RestClient.swift
/// rather than the official supabase-swift SDK — see RestClient's header
/// comment for why (the SDK can't be built in Swift Playgrounds). Every
/// function here has the exact same signature it had when this called the
/// SDK, so nothing above this file (DrinkMatchStore, any view) needed to change.
enum SupabaseRepository {
    // MARK: - Auth

    static func signInWithApple(idToken: String) async throws -> UUID {
        try await AuthManager.shared.signInWithApple(idToken: idToken)
    }

    static func signOut() async throws {
        try await AuthManager.shared.signOut()
    }

    /// Deletes the caller's auth.users row server-side, which cascades
    /// through every table via public.users.id's own cascade (see
    /// drinkmatch-backend's 20260801000014_account_deletion.sql). The local
    /// session is still valid afterward until it's cleared — callers should
    /// follow this with signOut().
    static func deleteAccount() async throws {
        try await PostgREST.rpcVoid("delete_own_account")
    }

    // MARK: - Profile

    static func fetchProfile(userID: UUID) async throws -> UserRow? {
        let rows: [UserRow] = try await PostgREST.select(
            "users",
            columns: "id,role,airline,base_airport,years_of_service,full_name,note,display_mode,nickname,verification_method,is_subscribed,birth_year",
            filters: [RestClient.eq("id", userID)],
            limit: 1
        )
        return rows.first
    }

    static func createProfile(_ params: CreateProfileParams) async throws -> UserRow {
        try await PostgREST.rpc("create_profile", params: params)
    }

    static func updateRole(userID: UUID, role: String) async throws {
        struct Patch: Encodable { var role: String }
        try await PostgREST.update("users", Patch(role: role), filters: [RestClient.eq("id", userID)])
    }

    static func updateAirline(userID: UUID, airline: String) async throws {
        struct Patch: Encodable { var airline: String }
        try await PostgREST.update("users", Patch(airline: airline), filters: [RestClient.eq("id", userID)])
    }

    static func updateDisplayPreference(userID: UUID, displayMode: DisplayMode, nickname: String) async throws {
        struct Patch: Encodable {
            var displayMode: String
            var nickname: String?
            enum CodingKeys: String, CodingKey { case displayMode = "display_mode", nickname }
        }
        let patch = Patch(displayMode: displayMode.rawValue, nickname: nickname.isEmpty ? nil : nickname)
        try await PostgREST.update("users", patch, filters: [RestClient.eq("id", userID)])
    }

    // MARK: - Schedule

    /// Scoped to one calendar month — the schedule editor can navigate to
    /// any month, and without this filter a user with saved entries in more
    /// than one real month would have their day-of-month numbers (the only
    /// thing `StayEntry.day` tracks — see NetworkConversions.swift) collide
    /// across months.
    static func fetchSchedule(userID: UUID, year: Int, month: Int) async throws -> [ScheduleEntryRow] {
        let start = postgresDateString(year: year, month: month, forDay: 1)
        let (nextYear, nextMonth) = month == 12 ? (year + 1, 1) : (year, month + 1)
        let end = postgresDateString(year: nextYear, month: nextMonth, forDay: 1)
        return try await PostgREST.select(
            "schedule_entries",
            columns: "id,day,airport_code,available_from,visible_to_strangers",
            filters: [RestClient.eq("user_id", userID), RestClient.gte("day", start), RestClient.lt("day", end)],
            order: "day.asc"
        )
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
        let rows: [Row] = try await PostgREST.select(
            "schedule_visibility_exceptions",
            columns: "schedule_entry_id,hidden_from_user_id",
            filters: [RestClient.inList("schedule_entry_id", entryIDs.map(\.uuidString))]
        )
        return Dictionary(grouping: rows, by: \.scheduleEntryId).mapValues { $0.map(\.hiddenFromUserId) }
    }

    /// Upserts one day's entry (unique on `user_id, day`) and replaces its
    /// hidden-from set, returning the row's id for further edits.
    @discardableResult
    static func upsertScheduleEntry(userID: UUID, year: Int, month: Int, day: Int, location: String, from: String, hiddenFrom: [UUID], visibleToStrangers: Bool) async throws -> UUID {
        let payload = ScheduleEntryInsert(
            userId: userID,
            day: postgresDateString(year: year, month: month, forDay: day),
            airportCode: location,
            availableFrom: postgresTimeString(fromClientTime: from),
            visibleToStrangers: visibleToStrangers
        )
        let row: ScheduleEntryRow = try await PostgREST.upsertReturningFirst(
            "schedule_entries", payload, onConflict: "user_id,day", select: "id,day,airport_code,available_from,visible_to_strangers"
        )

        try await PostgREST.delete("schedule_visibility_exceptions", filters: [RestClient.eq("schedule_entry_id", row.id)])
        if !hiddenFrom.isEmpty {
            let inserts = hiddenFrom.map { VisibilityExceptionInsert(scheduleEntryId: row.id, hiddenFromUserId: $0) }
            try await PostgREST.insert("schedule_visibility_exceptions", inserts)
        }
        return row.id
    }

    static func deleteScheduleEntry(id: UUID) async throws {
        try await PostgREST.delete("schedule_entries", filters: [RestClient.eq("id", id)])
    }

    // MARK: - Verification / referral codes

    static func verifyEmailDomain(email: String) async throws -> Bool {
        try await PostgREST.rpc("verify_email_domain", params: EmailParams(email: email))
    }

    static func issueReferralCode() async throws -> String {
        try await PostgREST.rpc("issue_referral_code")
    }

    static func redeemReferralCode(code: String) async throws {
        try await PostgREST.rpcVoid("redeem_referral_code", params: CodeParams(code: code))
    }

    static func fetchMyReferralCodes(userID: UUID) async throws -> [(code: String, used: Bool)] {
        struct Row: Decodable { var code: String; var used: Bool }
        let rows: [Row] = try await PostgREST.select(
            "referral_codes", columns: "code,used",
            filters: [RestClient.eq("issued_by_user_id", userID)], order: "created_at.asc"
        )
        return rows.map { (code: $0.code, used: $0.used) }
    }

    // MARK: - Friends

    static func issueInviteCode() async throws -> String {
        try await PostgREST.rpc("issue_invite_code")
    }

    static func redeemInviteCode(code: String) async throws {
        try await PostgREST.rpcVoid("redeem_invite_code", params: CodeParams(code: code))
    }

    static func fetchFriendsWithOverlap() async throws -> [FriendOverlapRow] {
        try await PostgREST.rpc("list_friends_with_overlap")
    }

    static func fetchMyInviteCodes(userID: UUID) async throws -> [(code: String, used: Bool)] {
        struct Row: Decodable { var code: String; var used: Bool }
        let rows: [Row] = try await PostgREST.select(
            "invite_codes", columns: "code,used",
            filters: [RestClient.eq("owner_user_id", userID)], order: "created_at.asc"
        )
        return rows.map { (code: $0.code, used: $0.used) }
    }

    // MARK: - Strangers

    static func searchStrangerCandidates(baseAirport: String?, role: String?) async throws -> [StrangerCandidateRow] {
        let params = StrangerSearchParams(
            baseAirport: (baseAirport == "ALL" ? nil : baseAirport),
            role: (role == "ALL" ? nil : role)
        )
        return try await PostgREST.rpc("search_stranger_candidates", params: params)
    }

    static func passCandidate(userID: UUID, candidateID: UUID) async throws {
        try await PostgREST.insert("passed_candidates", PassedCandidateInsert(userId: userID, candidateUserId: candidateID))
    }

    // MARK: - Overlap

    static func fetchOverlap(otherUserID: UUID) async throws -> [StayOverlap] {
        let rows: [MatchOverlapRow] = try await PostgREST.rpc("get_match_overlap", params: OtherUserParams(otherUserId: otherUserID))
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
        try await PostgREST.select("offers", columns: "id,from_user_id,to_user_id,day,airport_code,auto_accept,status")
    }

    static func createOffer(toUserID: UUID, day: Int, location: String, autoAccept: Bool) async throws -> UUID {
        let params = CreateOfferParams(toUserId: toUserID, day: postgresDateString(forDay: day), airportCode: location, autoAccept: autoAccept)
        return try await PostgREST.rpc("create_offer", params: params)
    }

    static func acceptOffer(offerID: UUID) async throws {
        try await PostgREST.rpcVoid("accept_offer", params: OfferIDParams(offerId: offerID))
    }

    static func fetchOfferCounterpart(offerID: UUID) async throws -> OfferCounterpartRow? {
        let rows: [OfferCounterpartRow] = try await PostgREST.rpc("get_offer_counterpart", params: OfferIDParams(offerId: offerID))
        return rows.first
    }

    /// The matched partner's stay calendar for an accepted offer (the green
    /// tappable days in the client's ReadOnlyStayCalendar) — only callable
    /// once accepted, and already excludes days the partner hid from us.
    static func fetchMatchCalendar(offerID: UUID) async throws -> [ScheduleEntryRow] {
        try await PostgREST.rpc("get_match_calendar", params: OfferIDParams(offerId: offerID))
    }

    // MARK: - Group offers

    static func fetchMyGroups() async throws -> [GroupOfferRow] {
        try await PostgREST.select("group_offers", columns: "id,day,airport_code,created_by_user_id")
    }

    static func createGroupOffer(day: Int, location: String, memberIDs: [UUID], autoAccept: Bool) async throws -> UUID {
        let params = CreateGroupOfferParams(day: postgresDateString(forDay: day), airportCode: location, memberIds: memberIDs, autoAccept: autoAccept)
        return try await PostgREST.rpc("create_group_offer", params: params)
    }

    static func acceptGroupOfferMembership(groupOfferID: UUID) async throws {
        try await PostgREST.rpcVoid("accept_group_offer_membership", params: GroupOfferIDParams(groupOfferId: groupOfferID))
    }

    static func fetchGroupMembersInfo(groupOfferID: UUID) async throws -> [GroupMemberInfoRow] {
        try await PostgREST.rpc("get_group_offer_members_info", params: GroupOfferIDParams(groupOfferId: groupOfferID))
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
        return try await PostgREST.rpc("send_proposal", params: params)
    }

    static func fetchProposal(offerID: UUID) async throws -> ProposalRow? {
        let rows: [ProposalRow] = try await PostgREST.select(
            "proposals", columns: "id,offer_id,group_offer_id,day,airport_code,meeting_time,place",
            filters: [RestClient.eq("offer_id", offerID)], limit: 1
        )
        return rows.first
    }

    static func fetchProposal(groupOfferID: UUID) async throws -> ProposalRow? {
        let rows: [ProposalRow] = try await PostgREST.select(
            "proposals", columns: "id,offer_id,group_offer_id,day,airport_code,meeting_time,place",
            filters: [RestClient.eq("group_offer_id", groupOfferID)], limit: 1
        )
        return rows.first
    }

    // MARK: - Billing

    /// Calls drinkmatch-backend's verify-purchase Edge Function right after
    /// a local StoreKit 2 purchase, so the caller unlocks stranger-matching
    /// immediately instead of waiting on Apple's async server notification.
    static func verifyPurchase(transactionJWS: String) async throws {
        try await PostgREST.invokeFunction("verify-purchase", body: VerifyPurchaseBody(transactionJWS: transactionJWS))
    }

    // MARK: - Report / block

    static func blockUser(userID: UUID) async throws {
        try await PostgREST.rpcVoid("block_user", params: BlockUserParams(userId: userID))
    }

    static func unblockUser(userID: UUID) async throws {
        try await PostgREST.rpcVoid("unblock_user", params: BlockUserParams(userId: userID))
    }

    static func fetchBlockedUsers() async throws -> [BlockedUserRow] {
        try await PostgREST.rpc("list_blocked_users")
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
        return try await PostgREST.rpc("submit_report", params: params)
    }

    // MARK: - Notifications

    static func fetchNotifications() async throws -> [NotificationRow] {
        try await PostgREST.select("notifications", columns: "id,type,body,read", order: "created_at.desc")
    }

    static func markAllNotificationsRead(userID: UUID) async throws {
        try await PostgREST.update(
            "notifications", ReadFlagUpdate(read: true),
            filters: [RestClient.eq("user_id", userID), RestClient.eq("read", false)]
        )
    }

    // MARK: - Push notifications

    /// `push_tokens` is fully self-managed by the client (see its
    /// `push_tokens_owner_all` RLS policy — no RPC needed). Upserts on the
    /// table's `unique (platform, token)` constraint so re-registering the
    /// same device (reinstall, or a different account signing in on it)
    /// updates `user_id` instead of erroring.
    static func registerPushToken(userID: UUID, token: String) async throws {
        try await PostgREST.upsert("push_tokens", PushTokenInsert(userId: userID, platform: "ios", token: token), onConflict: "platform,token")
    }
}
