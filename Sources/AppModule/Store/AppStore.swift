import Foundation
import Observation

/// Single source of truth for the whole demo app. Everything here is
/// in-memory only (no persistence, no network) — this mirrors the React
/// prototype's local `useState` model while the backend design (handoff
/// doc §7-8) is implemented separately.
@Observable
final class AppStore {
    var profile: UserProfile?
    var mySchedule: [StayEntry] = []

    var screen: AppScreen = .profile
    var mode: MatchMode = .friends

    var matches: [MatchedPerson] = []
    var passed: Set<Int> = []
    var friends: [Person] = SampleFriends.initial
    var groups: [DrinkGroup] = []

    var verification: VerificationMethod?
    var isSubscribed = false

    var notifications: [AppNotification] = []
    var referralCodes: [String: ReferralCodeEntry] = SampleReferralCodes.initial
    var myReferralCodes: [String] = []

    var isVerified: Bool { verification != nil }
    var unreadNotificationCount: Int { notifications.filter { !$0.read }.count }

    // MARK: - Onboarding

    func completeProfile(_ profile: UserProfile) {
        self.profile = profile
        screen = .schedule
    }

    func completeSchedule(_ entries: [StayEntry]) {
        mySchedule = entries
        screen = .main
    }

    // MARK: - Notifications

    func addNotification(_ body: String) {
        notifications.append(AppNotification(id: UUID().uuidString, body: body, read: false))
    }

    func markAllNotificationsRead() {
        for index in notifications.indices { notifications[index].read = true }
    }

    // MARK: - Verification / billing (demo only — no real checks)

    func markVerified(_ method: VerificationMethod) {
        verification = method
    }

    func markSubscribed() {
        isSubscribed = true
    }

    func useReferralCode(_ code: String) {
        referralCodes[code]?.used = true
    }

    func generateReferralCode() {
        guard myReferralCodes.count < maxReferralCodesPerUser else { return }
        let suffix = UUID().uuidString.prefix(4).uppercased()
        let code = "SENPAI-\(suffix)"
        myReferralCodes.append(code)
        let referrerName = profile?.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        referralCodes[code] = ReferralCodeEntry(referrerName: (referrerName?.isEmpty == false ? referrerName! : "あなた"), used: false)
    }

    // MARK: - Friends

    /// Adds a friend by invite code. Returns nil on success, or an error
    /// message to show inline.
    func addFriend(byInviteCode rawCode: String) -> String? {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let person = InviteCodes.all[code] else {
            return "招待コードが見つかりません(例: PILOT2024, CREW-AYA)"
        }
        guard !friends.contains(where: { $0.id == person.id }) else {
            return "すでに追加済みです"
        }
        friends.append(person)
        return nil
    }

    // MARK: - 1:1 offers

    func sendOffer(to person: Person, autoAccept: Bool) {
        guard !matches.contains(where: { $0.id == person.id }) else { return }
        let status: OfferStatus = autoAccept ? .accepted : .pending
        matches.append(MatchedPerson(person: person, status: status))
        if status == .accepted {
            addNotification("\(person.fullName ?? person.name)さんとマッチが成立しました")
        }
    }

    func pass(_ person: Person) {
        passed.insert(person.id)
    }

    /// Demo-only: simulate the other side accepting a pending offer.
    func simulateAccept(personID: Int) {
        guard let index = matches.firstIndex(where: { $0.id == personID }) else { return }
        matches[index].status = .accepted
        let person = matches[index].person
        addNotification("\(person.fullName ?? person.name)さんが誘いを承諾し、マッチが成立しました")
    }

    func status(for personID: Int) -> OfferStatus? {
        matches.first { $0.id == personID }?.status
    }

    // MARK: - Group offers

    func createGroupOffer(day: Int, location: String, members: [Person], autoAccept: Bool) {
        guard !members.isEmpty else { return }
        let id = "g_\(day)_\(location)_\(UUID().uuidString.prefix(6))"
        let groupMembers = members.map { GroupMember(person: $0, status: autoAccept ? .accepted : .pending) }
        groups.append(DrinkGroup(id: id, day: day, location: location, members: groupMembers))
        addNotification("\(fmtDate(day)) \(airportLabel(location))のグループを作成しました(\(members.count)人を招待)")
    }

    /// Demo-only: simulate a group member accepting.
    func acceptGroupMember(groupID: String, memberID: Int) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else { return }
        guard let memberIndex = groups[groupIndex].members.firstIndex(where: { $0.id == memberID }) else { return }
        groups[groupIndex].members[memberIndex].status = .accepted
        let member = groups[groupIndex].members[memberIndex]
        addNotification("\(member.person.fullName ?? member.person.name)さんがグループへの参加を承諾しました")
    }

    // MARK: - Proposals

    func sendProposal(personID: Int, day: Int, location: String, time: String, place: String) {
        guard let index = matches.firstIndex(where: { $0.id == personID }) else { return }
        matches[index].sentProposal = Proposal(day: day, location: location, time: time, place: place)
        let person = matches[index].person
        addNotification("集合案を送信しました(\(person.fullName ?? person.name)さん宛)")
    }

    func sendGroupProposal(groupID: String, time: String, place: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let group = groups[index]
        groups[index].sentProposal = Proposal(day: group.day, location: group.location, time: time, place: place)
        addNotification("集合案を送信しました(\(fmtDate(group.day)) \(airportLabel(group.location))のグループ宛)")
    }
}
