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

/// One "day off" entry in a user's monthly schedule: where they'll be
/// staying and from what time they're free to meet up.
struct StayEntry: Identifiable, Hashable {
    var day: Int
    var location: String = ""
    var from: String = "19:00"
    /// Friend ids this entry is hidden from (friends-matching privacy only).
    var hiddenFrom: [Int] = []
    var id: Int { day }
}

/// A fellow crew member, whether a known friend, someone found through an
/// invite/referral code, or a stranger surfaced by new-match search.
struct Person: Identifiable, Hashable {
    var id: Int
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

enum OfferStatus: String, Hashable {
    case pending
    case accepted
}

/// A person you've sent (or received) a 1:1 drink offer with.
struct MatchedPerson: Identifiable, Hashable {
    var person: Person
    var status: OfferStatus
    var sentProposal: Proposal? = nil
    var id: Int { person.id }
}

/// A member of a group offer, with their own independent accept status.
struct GroupMember: Identifiable, Hashable {
    var person: Person
    var status: OfferStatus
    var id: Int { person.id }
}

/// A group drink invitation tied to one shared day + stay airport.
struct DrinkGroup: Identifiable {
    var id: String
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

enum DisplayMode: String, Hashable {
    case initials
    case nickname
}

/// The signed-in user's profile, including how they want to appear to
/// strangers in the new-match flow.
struct UserProfile {
    var role: String
    var base: String
    var fullName: String
    var displayMode: DisplayMode
    var nickname: String

    /// Name shown to strangers: nickname if chosen, otherwise generated initials.
    var strangerDisplayName: String {
        switch displayMode {
        case .nickname:
            return nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        case .initials:
            return computeInitials(fullName)
        }
    }
}

enum VerificationMethod {
    case email(String)
    case referral(referrerName: String)
}

/// A single-use referral code issued by an already-verified user, used as an
/// alternative identity-verification route for the new-match flow.
struct ReferralCodeEntry {
    var referrerName: String
    var used: Bool
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
