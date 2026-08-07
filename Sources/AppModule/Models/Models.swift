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
    /// Friend user ids this entry is hidden from (friends-matching privacy only).
    var hiddenFrom: [UUID] = []
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
    var id: Int { day }
}

enum OfferStatus: String, Hashable, Codable {
    case pending
    case accepted
    case expired
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

/// The signed-in user's profile, including how they want to appear to
/// strangers in the new-match flow.
struct UserProfile {
    var role: String
    var base: String
    var fullName: String
    var displayMode: DisplayMode
    var nickname: String
    var airline: String = ""

    /// Name shown to strangers: nickname if chosen, otherwise generated initials.
    var strangerDisplayName: String {
        switch displayMode {
        case .nickname:
            return nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        case .initials:
            return initials(from: fullName)
        }
    }
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

/// 1-on-1 vs. group-offer sub-tab, shared by both matching modes.
enum OfferTabMode: String, CaseIterable, Hashable {
    case individual
    case group
}
