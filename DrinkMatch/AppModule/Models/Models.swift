import Foundation

/// One of the eight aviation job categories the app is scoped to.
struct Role: Identifiable, Hashable {
    var code: String
    var label: String
    var id: String { code }
}

/// A selectable stay-location airport (domestic + international).
struct Airport: Identifiable, Hashable {
    var code: String
    var name: String
    var id: String { code }
}

/// A selectable employer airline, identified by its 3-letter ICAO code.
struct Airline: Identifiable, Hashable {
    var code: String
    var name: String
    var id: String { code }
}

/// One "day off" entry in a user's monthly schedule: where they'll be
/// staying and from what time they're free to meet up.
struct StayEntry: Identifiable, Hashable {
    var day: Int
    var location: String = ""
    var from: String = "19:00"
    /// Optional cutoff time on `day + 1`, for a stay that runs overnight
    /// (e.g. land at 21:00, leave the next day by 17:00) — nil means no
    /// next-day extension, i.e. this entry only covers `day` itself, same
    /// as before this field existed.
    var until: String? = nil
    /// Friend user ids this entry is hidden from (friends-matching privacy only).
    var hiddenFrom: [UUID] = []
    /// Off by default: schedule entries are friends-only unless explicitly
    /// opted into "新しい人を探す" visibility for that specific day. Enforced
    /// server-side by `_schedule_overlap()`, not just a display-layer hint.
    var visibleToStrangers: Bool = false
    var id: Int { day }
}

/// A fellow crew member, whether a known friend, someone found through an
/// invite/referral code, or a stranger surfaced by new-match search.
struct Person: Identifiable, Hashable {
    var id: UUID
    /// Short display name (initials, nickname, or short form) always safe to show.
    var name: String
    /// Full name — only present for verified acquaintances (friends), never
    /// shown in the stranger-matching flow.
    var fullName: String?
    var role: String
    var airline: String
    var base: String
    var years: Int
    var note: String
    var stays: [StayEntry]
    /// Self-reported, year-only (see UserProfile.birthYear) — nil if the
    /// person never set it. Only meaningful for stranger-search candidates,
    /// where it powers the age-difference filter in StrangersTabView.
    var birthYear: Int? = nil
    /// LINE ID, phone number, etc. — only ever populated once a match is
    /// actually accepted (see get_offer_counterpart/get_group_offer_members_info
    /// in drinkmatch-backend); nil everywhere else, including a pending offer.
    var contactInfo: String? = nil

    func displayName(showFullName: Bool) -> String {
        showFullName ? (fullName ?? name) : name
    }
}

/// One overlapping stay between the signed-in user and another person: same
/// day + same stay airport, on both sides. Pre-computed server-side via the
/// backend's `get_match_overlap` RPC (see SupabaseRepository.fetchOverlap) —
/// the client never sees another user's raw schedule.
struct StayOverlap: Identifiable, Hashable {
    var day: Int
    var location: String
    var myFrom: String
    var otherFrom: String
    /// Set only when one side's stay spans into this day from an overnight
    /// entry made the day before — the time they need to leave by. Nil
    /// means no known cutoff for that side on this day.
    var myUntil: String?
    var otherUntil: String?
    var id: Int { day }
}

enum OfferStatus: String, Hashable, Codable {
    case pending
    case accepted
    case expired
    case cancelled
}

/// A person you've sent (or received) a 1:1 drink offer with.
struct MatchedPerson: Identifiable, Hashable {
    var person: Person
    /// The underlying `offers` row id — needed for accept/proposal calls,
    /// which act on a specific offer, not just "this person" (the backend
    /// pins an offer to one day + airport; see PersonCardView.onOffer).
    var offerID: UUID
    var status: OfferStatus
    /// True if this offer was sent *to* me (I can accept it); false if I
    /// sent it (only the recipient can accept — `accept_offer` is
    /// `to_user_id = auth.uid()`-scoped server-side).
    var isIncoming: Bool
    var sentProposal: Proposal? = nil
    var id: UUID { person.id }
}

/// A member of a group offer, with their own independent accept status.
struct GroupMember: Identifiable, Hashable {
    var person: Person
    var status: OfferStatus
    var id: UUID { person.id }
}

/// A group drink invitation tied to one shared day + stay airport.
struct GroupOffer: Identifiable {
    var id: UUID
    var day: Int
    var location: String
    var members: [GroupMember]
    var sentProposal: Proposal? = nil

    var acceptedCount: Int { members.filter { $0.status == .accepted }.count }
}

/// A concrete meetup proposal (time + place) sent after a match/group accepts.
struct Proposal: Hashable {
    var day: Int
    var location: String
    var time: String
    var place: String
}

struct AppNotification: Identifiable {
    var id: String
    var body: String
    var read: Bool
}

enum DisplayMode: String, Hashable, Codable {
    case initials
    case nickname
}

/// Matches the backend's `report_reason` Postgres enum
/// (drinkmatch-backend's 20260801000011_reports_and_blocks.sql) — rawValue
/// is sent verbatim as the `submit_report` RPC's `p_reason` argument.
enum ReportReason: String, CaseIterable, Identifiable, Hashable {
    case harassment
    case inappropriateContent = "inappropriate_content"
    case fakeProfile = "fake_profile"
    case safetyConcern = "safety_concern"
    case spam
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .harassment: return "嫌がらせ・迷惑行為"
        case .inappropriateContent: return "不適切なコンテンツ"
        case .fakeProfile: return "なりすまし・虚偽のプロフィール"
        case .safetyConcern: return "安全上の懸念"
        case .spam: return "スパム"
        case .other: return "その他"
        }
    }
}

/// A user this account has blocked — see the "ブロック中のユーザー"
/// management screen reachable from MainView.
struct BlockedUser: Identifiable, Hashable {
    var userID: UUID
    var displayName: String
    var id: UUID { userID }
}

/// An incoming request from someone who entered this user's invite code —
/// shown with full identity (not the stranger-safe display name) since
/// invite codes are for people who already know each other in person; see
/// DrinkMatchStore.respondToFriendRequest.
struct FriendRequest: Identifiable, Hashable {
    var id: UUID
    var fromUserID: UUID
    var fullName: String
    var role: String
    var airline: String
    var base: String
}

/// A persistent circle of people for group-wide schedule matching — distinct
/// from GroupOffer, which is a one-shot invitation tied to a single
/// already-chosen day/airport. See MemberGroupDetailView.
struct MemberGroup: Identifiable, Hashable {
    var id: UUID
    var name: String
    var inviteCode: String
    var memberCount: Int
    var createdByUserID: UUID
}

/// A fellow group member, shown with full identity like FriendRequest —
/// group members are assumed to already know each other in person.
struct MemberGroupPerson: Identifiable, Hashable {
    var userID: UUID
    var fullName: String
    var role: String
    var airline: String
    var base: String
    var id: UUID { userID }
}

/// An incoming request to join a group, sent by an existing member who
/// added this user directly (as opposed to this user joining via the
/// group's invite code, which needs no approval).
struct MemberGroupInvite: Identifiable, Hashable {
    var id: UUID
    var groupID: UUID
    var groupName: String
    var fromUserID: UUID
    var fromFullName: String
    var fromRole: String
    var fromAirline: String
    var fromBase: String
}

/// One ranked row in a group's schedule ranking: a day+airport combination
/// and which members are free then, most-overlapping first.
struct MemberGroupScheduleMatch: Identifiable, Hashable {
    var day: Int
    var location: String
    var memberNames: [String]
    var id: String { "\(day)-\(location)" }
}

/// The signed-in user's profile, including how they want to appear to
/// strangers in the new-match flow.
struct UserProfile {
    var role: String
    var base: String
    var fullName: String
    var displayMode: DisplayMode
    var nickname: String
    var airline: String = ""
    /// Self-reported birth year only, not a full birthdate — enough for an
    /// approximate age-difference filter in stranger search without storing
    /// anything more identifying. Optional; nil means the user hasn't set it.
    var birthYear: Int? = nil
    /// How many times birth year has been changed after onboarding —
    /// `update_birth_year()` on the backend rejects a change once this
    /// reaches 2 (the initial onboarding-time set via create_profile
    /// doesn't count). Defaults to 0 for the same freshly-onboarded reason
    /// as identityUpdatedAt below.
    var birthYearChangeCount: Int = 0
    /// When role/airline/base were last changed — `update_identity()` on
    /// the backend rejects another change within 30 days of this. Defaults
    /// to distant past so a freshly-onboarded profile (which hasn't round-
    /// tripped through the server yet) never looks like it's on cooldown.
    var identityUpdatedAt: Date = .distantPast
    /// LINE ID, phone number, etc. — only ever shared with someone once a
    /// match with them is accepted (see Person.contactInfo). Optional; nil
    /// means the user hasn't set one.
    var contactInfo: String? = nil

    /// Name shown to strangers: nickname if chosen, otherwise generated initials.
    var strangerDisplayName: String {
        switch displayMode {
        case .nickname:
            return nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        case .initials:
            return initials(from: fullName)
        }
    }

    /// Mirrors update_identity()'s server-side 30-day cooldown so the UI can
    /// disable editing and show the next-eligible date proactively, instead
    /// of only finding out after a failed attempt. The server is still the
    /// real enforcement point — this is a display convenience only.
    var nextIdentityEditDate: Date {
        identityUpdatedAt.addingTimeInterval(30 * 24 * 60 * 60)
    }

    var canEditIdentity: Bool { Date() >= nextIdentityEditDate }

    /// Mirrors update_birth_year()'s server-side 2-change cap so the UI can
    /// hide the edit button once it's used up, instead of only finding out
    /// after a failed attempt. The server is still the real enforcement point.
    var canEditBirthYear: Bool { birthYearChangeCount < 2 }
}

/// Top-level screen the root view is currently showing.
enum AppScreen {
    case profile
    case schedule
    case main
    case matches
}

/// Friends vs. strangers matching mode on the main screen.
enum MatchMode: String, CaseIterable, Hashable {
    case friends
    case strangers
}

/// 1-on-1 matching vs. persistent member groups on the main screen —
/// independent of MatchMode (friends/strangers), which only applies within
/// the 1-on-1 side.
enum ContactMode: String, CaseIterable, Hashable {
    case oneOnOne
    case groups
}

/// 1-on-1 vs. group-offer sub-tab within the strangers tab (see
/// OfferTabModeSwitcher) — friends have no offer flow.
enum OfferTabMode: String, CaseIterable, Hashable {
    case individual
    case group
}
