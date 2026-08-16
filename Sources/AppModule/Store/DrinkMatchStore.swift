import Foundation
import Observation
import StoreKit

/// Single source of truth for the app, backed by the drinkmatch-backend
/// Supabase project. Network I/O + DTO mapping lives in SupabaseRepository;
/// this class owns app state and the business-facing async operations views
/// call. All mutation happens on the main actor (SwiftUI's requirement),
/// with network awaits suspending in between.
@MainActor
@Observable
final class DrinkMatchStore {
    var authUserID: UUID?
    /// The email address this session is signed in with — surfaced in
    /// ProfileInfoView since Sign in with Apple's account picker doesn't
    /// otherwise make it obvious which address is currently active.
    var authEmail: String?
    var isBootstrapping = true

    var profile: UserProfile?
    var mySchedule: [StayEntry] = []
    /// Which month `mySchedule`/`scheduleEntryIDs` currently reflects —
    /// moves together with them, whether from the initial post-sign-in load
    /// or from the schedule editor navigating to a different month.
    var scheduleYear = BoardCalendar.year
    var scheduleMonth = BoardCalendar.month
    private var scheduleEntryIDs: [Int: UUID] = [:]

    var screen: AppScreen = .profile
    var mode: MatchMode = .friends

    var friends: [Person] = []
    var strangerCandidates: [Person] = []
    /// Shown on PaywallGateView, before subscribing — nil while loading or
    /// if it failed to load (never surfaced as an error; it's a nice-to-have
    /// preview, not required to use the app).
    var strangerCandidateCount: Int?
    /// Per-candidate/friend day-by-day overlap, fetched via `get_match_overlap`
    /// once a candidate list loads — see the note on PersonCardView.overlap.
    var overlapCache: [UUID: [StayOverlap]] = [:]

    var matches: [MatchedPerson] = []
    var groups: [GroupOffer] = []

    var isVerified = false
    var isSubscribed = false
    /// Same catalog product for every account, so unlike the rest of this
    /// state it's not cleared on sign-out in resetLocalState().
    var subscriptionProduct: Product?
    var isPurchasing = false

    var notifications: [AppNotification] = []
    var myReferralCodes: [(code: String, used: Bool)] = []
    var myInviteCodes: [(code: String, used: Bool)] = []
    var blockedUsers: [BlockedUser] = []

    var lastErrorMessage: String?

    var unreadNotificationCount: Int { notifications.filter { !$0.read }.count }

    // MARK: - Auth / bootstrap

    /// Checks for a session persisted from a previous launch (see
    /// AuthManager/KeychainStore) — there's no continuous auth-state stream
    /// to listen to now that this talks to Supabase's REST APIs directly
    /// (see RestClient's header comment), so sign-in/out below update
    /// `authUserID` themselves instead of relying on one.
    func bootstrap() async {
        if let userID = await AuthManager.shared.currentUserID {
            authUserID = userID
            authEmail = await AuthManager.shared.currentUserEmail
            await loadAfterSignIn(userID: userID)
        }
        isBootstrapping = false
    }

    /// Returns a status/error message to show inline, or nil on a
    /// session-issuing success.
    func signUpWithEmail(email: String, password: String) async -> String? {
        do {
            guard let userID = try await SupabaseRepository.signUpWithEmail(email: email, password: password) else {
                return "確認メールを送信しました。メール内のリンクを開いてからサインインしてください。"
            }
            authUserID = userID
            authEmail = await AuthManager.shared.currentUserEmail
            await loadAfterSignIn(userID: userID)
            return nil
        } catch {
            return "登録に失敗しました: \(error)"
        }
    }

    func signInWithEmail(email: String, password: String) async -> String? {
        do {
            let userID = try await SupabaseRepository.signInWithEmail(email: email, password: password)
            authUserID = userID
            authEmail = await AuthManager.shared.currentUserEmail
            await loadAfterSignIn(userID: userID)
            return nil
        } catch {
            return "サインインに失敗しました: \(error)"
        }
    }

    func requestPasswordReset(email: String) async -> String? {
        do {
            try await SupabaseRepository.requestPasswordReset(email: email)
            return "パスワード再設定メールを送信しました。メール内の「Reset password」リンクをコピーして貼り付けてください。"
        } catch {
            return "送信に失敗しました。メールアドレスをご確認ください。"
        }
    }

    /// Returns a status/error message to show inline, or nil on a
    /// session-issuing success (the user is signed in as a side effect).
    func resetPassword(resetLink: String, newPassword: String) async -> String? {
        do {
            let userID = try await SupabaseRepository.resetPassword(resetLink: resetLink, newPassword: newPassword)
            authUserID = userID
            authEmail = await AuthManager.shared.currentUserEmail
            await loadAfterSignIn(userID: userID)
            return nil
        } catch {
            // Temporary diagnostic: raw error, not the generic message —
            // revert once this flow is confirmed working on-device.
            return "パスワードの再設定に失敗しました: \(error)"
        }
    }

    func signOut() async {
        try? await SupabaseRepository.signOut()
        authUserID = nil
        resetLocalState()
    }

    /// Returns an error message on failure, or nil on success. Deleting
    /// auth.users server-side doesn't itself invalidate the client's
    /// existing session token, so this also signs out locally and resets
    /// state to match — otherwise every subsequent call would just fail
    /// against data that no longer exists.
    func deleteAccount() async -> String? {
        do {
            try await SupabaseRepository.deleteAccount()
        } catch {
            return "アカウントの削除に失敗しました。しばらくしてからもう一度お試しください。"
        }
        try? await SupabaseRepository.signOut()
        authUserID = nil
        resetLocalState()
        return nil
    }

    private func resetLocalState() {
        profile = nil
        mySchedule = []
        scheduleYear = BoardCalendar.year
        scheduleMonth = BoardCalendar.month
        scheduleEntryIDs = [:]
        friends = []
        strangerCandidates = []
        overlapCache = [:]
        matches = []
        groups = []
        isVerified = false
        isSubscribed = false
        notifications = []
        myReferralCodes = []
        myInviteCodes = []
        blockedUsers = []
        screen = .profile
        authEmail = nil
    }

    private func loadAfterSignIn(userID: UUID) async {
        do {
            if let row = try await SupabaseRepository.fetchProfile(userID: userID) {
                profile = row.asUserProfile
                isVerified = row.isVerified
                isSubscribed = row.isSubscribed
                await loadSchedule(userID: userID, year: BoardCalendar.year, month: BoardCalendar.month)
                screen = .main
            } else {
                screen = .profile
            }
        } catch {
            lastErrorMessage = "読み込みに失敗しました。"
        }
    }

    // MARK: - Onboarding

    func completeProfile(_ input: UserProfile, ageConfirmed: Bool) async {
        let params = CreateProfileParams(
            role: input.role,
            baseAirport: input.base,
            fullName: input.fullName,
            ageConfirmed: ageConfirmed,
            airline: input.airline,
            yearsOfService: nil,
            note: nil,
            displayMode: input.displayMode.rawValue,
            nickname: input.nickname.isEmpty ? nil : input.nickname,
            birthYear: input.birthYear
        )
        do {
            let row = try await SupabaseRepository.createProfile(params)
            profile = row.asUserProfile
            screen = .schedule
        } catch {
            lastErrorMessage = "プロフィールの保存に失敗しました。"
        }
    }

    func updateRole(_ role: String) async {
        guard let userID = authUserID else { return }
        let previous = profile?.role
        profile?.role = role
        do {
            try await SupabaseRepository.updateRole(userID: userID, role: role)
        } catch {
            profile?.role = previous ?? role
            lastErrorMessage = "職種の更新に失敗しました。"
        }
    }

    /// Required before "新しい人を探す" unlocks (see StrangersTabView's
    /// AirlineRequiredGateView) even though onboarding leaves it optional —
    /// asking for it upfront was too high a bar for people just trying the
    /// friends-matching feature.
    func updateAirline(_ airline: String) async {
        guard let userID = authUserID else { return }
        let previous = profile?.airline
        profile?.airline = airline
        do {
            try await SupabaseRepository.updateAirline(userID: userID, airline: airline)
        } catch {
            profile?.airline = previous ?? ""
            lastErrorMessage = "会社の更新に失敗しました。"
        }
    }

    func updateDisplayPreference(displayMode: DisplayMode, nickname: String) async {
        guard let userID = authUserID else { return }
        do {
            try await SupabaseRepository.updateDisplayPreference(userID: userID, displayMode: displayMode, nickname: nickname)
        } catch {
            lastErrorMessage = "表示名の更新に失敗しました。"
        }
    }

    // MARK: - Schedule

    @discardableResult
    func loadSchedule(userID: UUID, year: Int, month: Int) async -> [StayEntry] {
        do {
            let rows = try await SupabaseRepository.fetchSchedule(userID: userID, year: year, month: month)
            let hiddenMap = try await SupabaseRepository.fetchHiddenFrom(entryIDs: rows.map(\.id))
            var entries: [StayEntry] = []
            var idMap: [Int: UUID] = [:]
            for row in rows {
                guard var entry = row.asStayEntry else { continue }
                entry.hiddenFrom = hiddenMap[row.id] ?? []
                entries.append(entry)
                idMap[entry.day] = row.id
            }
            mySchedule = entries.sorted { $0.day < $1.day }
            scheduleEntryIDs = idMap
            scheduleYear = year
            scheduleMonth = month
            return mySchedule
        } catch {
            lastErrorMessage = "スケジュールの読み込みに失敗しました。"
            return []
        }
    }

    /// `year`/`month` is whatever the schedule editor was displaying at
    /// submit time — not necessarily `BoardCalendar`'s app-wide default, if
    /// the user navigated to a different month first. `mySchedule`/
    /// `scheduleEntryIDs` are already scoped to that same month (every
    /// navigation reloads them via `loadSchedule` above), so the
    /// removed-days diff below stays correct without needing those params.
    func completeSchedule(_ entries: [StayEntry], year: Int, month: Int) async {
        guard let userID = authUserID else { return }
        do {
            let removedDays = Set(mySchedule.map(\.day)).subtracting(entries.map(\.day))
            for day in removedDays {
                if let id = scheduleEntryIDs[day] {
                    try await SupabaseRepository.deleteScheduleEntry(id: id)
                    scheduleEntryIDs[day] = nil
                }
            }
            for entry in entries {
                let id = try await SupabaseRepository.upsertScheduleEntry(
                    userID: userID, year: year, month: month, day: entry.day, location: entry.location, from: entry.from,
                    hiddenFrom: entry.hiddenFrom, visibleToStrangers: entry.visibleToStrangers
                )
                scheduleEntryIDs[entry.day] = id
            }
            mySchedule = entries.sorted { $0.day < $1.day }
            scheduleYear = year
            scheduleMonth = month
            screen = .main
        } catch {
            lastErrorMessage = "スケジュールの保存に失敗しました。"
        }
    }

    // MARK: - Notifications

    func loadNotifications() async {
        do {
            notifications = try await SupabaseRepository.fetchNotifications().map(\.asAppNotification)
        } catch {
            lastErrorMessage = "通知の読み込みに失敗しました。"
        }
    }

    func markAllNotificationsRead() async {
        guard let userID = authUserID else { return }
        for index in notifications.indices { notifications[index].read = true }
        try? await SupabaseRepository.markAllNotificationsRead(userID: userID)
    }

    /// Requests permission and, if granted, registers the resulting device
    /// token server-side. Safe to call every time MainView appears — a
    /// denied/no-op request is cheap, and a granted one just re-registers
    /// the same token, which upserts (see SupabaseRepository.registerPushToken).
    ///
    /// Not currently called from any view: Swift Playgrounds cannot add the
    /// Push Notifications capability (confirmed via Apple's own developer
    /// forums — it needs Xcode, i.e. a Mac, which this project doesn't
    /// currently have access to), so registerForRemoteNotifications() would
    /// always fail. Wire `.task { await store.enablePushNotifications() }`
    /// back into MainView once that capability can actually be added.
    func enablePushNotifications() async {
        PushNotificationManager.configure { [weak self] token in
            Task { await self?.registerPushToken(token) }
        }
        await PushNotificationManager.requestAuthorization()
    }

    private func registerPushToken(_ token: String) async {
        guard let userID = authUserID else { return }
        try? await SupabaseRepository.registerPushToken(userID: userID, token: token)
    }

    // MARK: - Verification / referral codes / billing

    func verifyEmail(_ email: String) async -> Bool {
        do {
            let succeeded = try await SupabaseRepository.verifyEmailDomain(email: email)
            if succeeded { isVerified = true }
            return succeeded
        } catch {
            lastErrorMessage = "確認に失敗しました。"
            return false
        }
    }

    func redeemReferralCodeForVerification(_ code: String) async -> String? {
        guard !code.isEmpty else { return "本人確認コードを入力してください" }
        do {
            try await SupabaseRepository.redeemReferralCode(code: code)
            isVerified = true
            return nil
        } catch {
            switch BackendErrorCode.from(error) {
            case .referralCodeNotFound: return "本人確認コードが見つかりません"
            case .referralCodeAlreadyUsed: return "このコードはすでに使用されています"
            case .referralCodeSelfUse: return "自分が発行したコードは使用できません"
            default: return "確認に失敗しました"
            }
        }
    }

    func loadSubscriptionProduct() async {
        subscriptionProduct = try? await StoreKitManager.fetchSubscriptionProduct()
    }

    func purchaseSubscription() async {
        guard let product = subscriptionProduct, let userID = authUserID, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await StoreKitManager.purchase(product, appAccountToken: userID) {
            case .verified(let transaction, let jws):
                try await SupabaseRepository.verifyPurchase(transactionJWS: jws)
                await transaction.finish()
                await refreshSubscriptionStatus()
            case .pending, .userCancelled:
                break
            }
        } catch {
            lastErrorMessage = "購入の確認に失敗しました。しばらくしてからもう一度お試しください。"
        }
    }

    func restorePurchases() async {
        do {
            try await StoreKitManager.restorePurchases()
            await refreshSubscriptionStatus()
        } catch {
            lastErrorMessage = "購入履歴の復元に失敗しました。"
        }
    }

    /// Runs for the lifetime of the app (started as its own concurrent
    /// `.task` from RootView, alongside bootstrap()'s auth-state loop) —
    /// catches renewals/restores/Ask-to-Buy approvals that complete outside
    /// a direct purchaseSubscription() call, e.g. on another device.
    func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            try? await SupabaseRepository.verifyPurchase(transactionJWS: result.jwsRepresentation)
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }

    private func refreshSubscriptionStatus() async {
        guard let userID = authUserID else { return }
        if let row = try? await SupabaseRepository.fetchProfile(userID: userID) {
            isSubscribed = row.isSubscribed
        }
    }

    func loadMyReferralCodes() async {
        guard let userID = authUserID else { return }
        do {
            myReferralCodes = try await SupabaseRepository.fetchMyReferralCodes(userID: userID)
        } catch {
            lastErrorMessage = "本人確認コードの読み込みに失敗しました。"
        }
    }

    func generateReferralCode() async {
        do {
            _ = try await SupabaseRepository.issueReferralCode()
            await loadMyReferralCodes()
        } catch {
            lastErrorMessage = BackendErrorCode.from(error) == .referralCodeCapReached
                ? "本人確認コードの発行上限に達しています。"
                : "本人確認コードの発行に失敗しました。"
        }
    }

    // MARK: - Friends

    func loadFriends() async {
        do {
            let rows = try await SupabaseRepository.fetchFriendsWithOverlap()
            friends = rows.map(\.asPerson)
            await populateOverlapCache(for: rows.map(\.friendId))
        } catch {
            lastErrorMessage = "知り合いの読み込みに失敗しました。"
        }
    }

    func addFriend(byInviteCode rawCode: String) async -> String? {
        let code = rawCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return "招待コードを入力してください" }
        do {
            try await SupabaseRepository.redeemInviteCode(code: code)
            await loadFriends()
            return nil
        } catch {
            switch BackendErrorCode.from(error) {
            case .inviteCodeNotFound: return "招待コードが見つかりません"
            case .inviteCodeAlreadyUsed: return "すでに使用済みのコードです"
            case .inviteCodeSelfUse: return "自分のコードは使用できません"
            default: return "追加に失敗しました"
            }
        }
    }

    func loadMyInviteCodes() async {
        guard let userID = authUserID else { return }
        do {
            myInviteCodes = try await SupabaseRepository.fetchMyInviteCodes(userID: userID)
        } catch {
            lastErrorMessage = "招待コードの読み込みに失敗しました。"
        }
    }

    func generateInviteCode() async {
        do {
            _ = try await SupabaseRepository.issueInviteCode()
            await loadMyInviteCodes()
        } catch {
            lastErrorMessage = "招待コードの発行に失敗しました。"
        }
    }

    private func populateOverlapCache(for ids: [UUID]) async {
        await withTaskGroup(of: (UUID, [StayOverlap]).self) { group in
            for id in ids {
                group.addTask {
                    let overlap = (try? await SupabaseRepository.fetchOverlap(otherUserID: id)) ?? []
                    return (id, overlap)
                }
            }
            for await (id, overlap) in group {
                overlapCache[id] = overlap
            }
        }
    }

    // MARK: - Strangers

    func loadStrangerCandidateCount() async {
        strangerCandidateCount = try? await SupabaseRepository.countStrangerCandidates()
    }

    func loadStrangerCandidates(baseAirport: String, role: String) async {
        do {
            let rows = try await SupabaseRepository.searchStrangerCandidates(baseAirport: baseAirport, role: role)
            strangerCandidates = rows.map(\.asPerson)
            await populateOverlapCache(for: rows.map(\.candidateId))
        } catch {
            lastErrorMessage = "候補の読み込みに失敗しました。"
        }
    }

    func pass(_ person: Person) async {
        guard let userID = authUserID else { return }
        strangerCandidates.removeAll { $0.id == person.id }
        try? await SupabaseRepository.passCandidate(userID: userID, candidateID: person.id)
    }

    // MARK: - Offer / match status lookup

    func status(for personID: UUID) -> OfferStatus? {
        matches.first { $0.id == personID }?.status
    }

    // MARK: - Matches (offers + groups)

    func loadMatches() async {
        guard let myID = authUserID else { return }
        do {
            async let offerRowsTask = SupabaseRepository.fetchMyOffers()
            async let groupRowsTask = SupabaseRepository.fetchMyGroups()
            let (offerRows, groupRows) = try await (offerRowsTask, groupRowsTask)

            var newMatches: [MatchedPerson] = []
            for row in offerRows {
                guard let counterpart = try? await SupabaseRepository.fetchOfferCounterpart(offerID: row.id) else { continue }
                var person = counterpart.asPerson
                if row.status == .accepted {
                    let calendarRows = (try? await SupabaseRepository.fetchMatchCalendar(offerID: row.id)) ?? []
                    person.stays = calendarRows.compactMap(\.asStayEntry)
                }
                let sentProposal = (try? await SupabaseRepository.fetchProposal(offerID: row.id))?.asProposal
                newMatches.append(MatchedPerson(
                    person: person, offerID: row.id, status: row.status,
                    isIncoming: row.toUserId == myID, sentProposal: sentProposal
                ))
            }

            var newGroups: [GroupOffer] = []
            for row in groupRows {
                guard let day = dayOfMonth(fromPostgresDate: row.day) else { continue }
                let memberRows = (try? await SupabaseRepository.fetchGroupMembersInfo(groupOfferID: row.id)) ?? []
                let members = memberRows.map { GroupMember(person: $0.asPerson, status: $0.status) }
                let sentProposal = (try? await SupabaseRepository.fetchProposal(groupOfferID: row.id))?.asProposal
                newGroups.append(GroupOffer(id: row.id, day: day, location: row.airportCode, members: members, sentProposal: sentProposal))
            }

            matches = newMatches
            groups = newGroups
        } catch {
            lastErrorMessage = "マッチの読み込みに失敗しました。"
        }
    }

    func sendOffer(to person: Person, day: Int, location: String, autoAccept: Bool) async {
        guard !matches.contains(where: { $0.id == person.id }) else { return }
        do {
            _ = try await SupabaseRepository.createOffer(toUserID: person.id, day: day, location: location, autoAccept: autoAccept)
            await loadMatches()
        } catch {
            lastErrorMessage = "誘いの送信に失敗しました。"
        }
    }

    func acceptOffer(offerID: UUID) async {
        do {
            try await SupabaseRepository.acceptOffer(offerID: offerID)
            await loadMatches()
        } catch {
            lastErrorMessage = "承諾に失敗しました。"
        }
    }

    // MARK: - Group offers

    func createGroupOffer(day: Int, location: String, members: [Person], autoAccept: Bool) async {
        guard !members.isEmpty else { return }
        do {
            _ = try await SupabaseRepository.createGroupOffer(day: day, location: location, memberIDs: members.map(\.id), autoAccept: autoAccept)
            await loadMatches()
        } catch {
            lastErrorMessage = "グループの作成に失敗しました。"
        }
    }

    func acceptGroupMembership(groupOfferID: UUID) async {
        do {
            try await SupabaseRepository.acceptGroupOfferMembership(groupOfferID: groupOfferID)
            await loadMatches()
        } catch {
            lastErrorMessage = "参加の承諾に失敗しました。"
        }
    }

    // MARK: - Proposals

    func sendProposal(offerID: UUID, day: Int, location: String, time: String, place: String) async {
        do {
            _ = try await SupabaseRepository.sendProposal(day: day, location: location, time: time, place: place, offerID: offerID, groupOfferID: nil)
            await loadMatches()
        } catch {
            lastErrorMessage = "集合案の送信に失敗しました。"
        }
    }

    func sendGroupProposal(groupOfferID: UUID, time: String, place: String) async {
        guard let group = groups.first(where: { $0.id == groupOfferID }) else { return }
        do {
            _ = try await SupabaseRepository.sendProposal(day: group.day, location: group.location, time: time, place: place, offerID: nil, groupOfferID: groupOfferID)
            await loadMatches()
        } catch {
            lastErrorMessage = "集合案の送信に失敗しました。"
        }
    }

    // MARK: - Report / block

    /// Removes the blocked person from every local list — the backend also
    /// excludes them going forward, but the current screen shouldn't wait
    /// for a reload to reflect it.
    func blockUser(_ userID: UUID) async {
        do {
            try await SupabaseRepository.blockUser(userID: userID)
            friends.removeAll { $0.id == userID }
            strangerCandidates.removeAll { $0.id == userID }
            matches.removeAll { $0.id == userID }
            overlapCache[userID] = nil
            await loadBlockedUsers()
        } catch {
            lastErrorMessage = "ブロックに失敗しました。"
        }
    }

    func unblockUser(_ userID: UUID) async {
        do {
            try await SupabaseRepository.unblockUser(userID: userID)
            blockedUsers.removeAll { $0.userID == userID }
        } catch {
            lastErrorMessage = "ブロックの解除に失敗しました。"
        }
    }

    func loadBlockedUsers() async {
        do {
            blockedUsers = try await SupabaseRepository.fetchBlockedUsers().map(\.asBlockedUser)
        } catch {
            lastErrorMessage = "ブロック中のユーザーの読み込みに失敗しました。"
        }
    }

    /// Returns an error message to show the user, or nil on success.
    func submitReport(reportedUserID: UUID, reason: ReportReason, details: String, offerID: UUID? = nil, groupOfferID: UUID? = nil) async -> String? {
        do {
            _ = try await SupabaseRepository.submitReport(
                reportedUserID: reportedUserID, reason: reason,
                details: details.isEmpty ? nil : details, offerID: offerID, groupOfferID: groupOfferID
            )
            return nil
        } catch {
            return "報告の送信に失敗しました。"
        }
    }
}
