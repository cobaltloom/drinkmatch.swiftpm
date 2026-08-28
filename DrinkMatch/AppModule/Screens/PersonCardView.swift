import SwiftUI

/// A candidate row for 1:1 offers — shows overlap days/times and lets the
/// user send an offer (optionally auto-accepting), pass, or see the current
/// offer status.
struct PersonCardView: View {
    var person: Person
    /// Pre-computed by the store via the backend's `get_match_overlap` RPC —
    /// the client never sees another user's raw schedule (privacy), so this
    /// can't be computed locally the way the mock-data prototype did.
    var overlap: [StayOverlap]
    var offerStatus: OfferStatus?
    /// Needed to cancel a pending offer — nil whenever offerStatus is nil.
    var offerID: UUID?
    var showFullName: Bool
    /// Stranger search hides base airport (the user asked strangers not see
    /// where someone is based); friends still see it.
    var showBase: Bool
    /// Stranger search hides the airline too (the user asked strangers not
    /// see who someone works for); friends still see it. When false, the
    /// person's initials/nickname take the airline's place as the card's
    /// bold headline instead of trailing in parentheses.
    var showAffiliation: Bool
    var defaultAutoAccept: Bool
    /// The backend pins an offer to one specific day + airport at creation
    /// time (handoff doc §7's OFFERS.day/airport_code), so — unlike the
    /// mock-data prototype's single ambiguous "誘う" button — offering is
    /// per overlapping day, not per person. nil hides "🍻 誘う" entirely —
    /// friends are assumed to already have each other's contact info (LINE,
    /// etc.), so the in-app offer/accept flow is stranger-only.
    /// FriendsTabView passes nil for this reason; the overlap listing itself
    /// (which day + airport you're both free) still shows either way.
    var onOffer: ((Person, StayOverlap, Bool) -> Void)?
    /// nil hides "見送る" entirely — passing only means anything for
    /// stranger candidates (it hides them from future stranger search
    /// results server-side; see DrinkMatchStore.pass). A friend can't meaningfully
    /// be "passed": list_friends_with_overlap doesn't consult
    /// passed_candidates at all, so the button used to do nothing when
    /// shown on a friend card. FriendsTabView passes nil for this reason.
    var onPass: ((Person) -> Void)?
    /// nil hides the "キャンセル" button entirely, same rationale as onOffer
    /// being nil for FriendsTabView — cancelling is only meaningful for a
    /// stranger offer sent through this card's own "🍻 誘う" button.
    var onCancelOffer: ((UUID) -> Void)?
    var onReport: (Person, ReportReason, String) async -> String?
    var onBlock: (Person) async -> Void

    @State private var autoAccept: Bool
    @State private var showingReportSheet = false

    private var affiliationLine: String? {
        var parts: [String] = []
        if !person.airline.isEmpty { parts.append(person.airline) }
        if showBase && !person.base.isEmpty { parts.append(person.base) }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    init(person: Person, overlap: [StayOverlap], offerStatus: OfferStatus?, offerID: UUID? = nil, showFullName: Bool,
         showBase: Bool,
         showAffiliation: Bool = true,
         defaultAutoAccept: Bool,
         onOffer: ((Person, StayOverlap, Bool) -> Void)?, onPass: ((Person) -> Void)?,
         onCancelOffer: ((UUID) -> Void)? = nil,
         onReport: @escaping (Person, ReportReason, String) async -> String?, onBlock: @escaping (Person) async -> Void) {
        self.person = person
        self.overlap = overlap
        self.offerStatus = offerStatus
        self.offerID = offerID
        self.showFullName = showFullName
        self.showBase = showBase
        self.showAffiliation = showAffiliation
        self.defaultAutoAccept = defaultAutoAccept
        self.onOffer = onOffer
        self.onPass = onPass
        self.onCancelOffer = onCancelOffer
        self.onReport = onReport
        self.onBlock = onBlock
        _autoAccept = State(initialValue: autoAcceptOfferFeatureEnabled && defaultAutoAccept)
    }

    var body: some View {
        BoardCard {
            HStack(alignment: .firstTextBaseline) {
                Text(person.role).splitFlap(13, weight: .bold).foregroundStyle(Theme.amber)
                Spacer()
                Text(overlap.isEmpty ? "共通ステイ先なし" : "同じステイ先あり")
                    .font(.system(size: 11))
                    .foregroundStyle(overlap.isEmpty ? Theme.red : Theme.green)
                Button {
                    showingReportSheet = true
                } label: {
                    Image(systemName: "flag")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if showAffiliation, let affiliationLine {
                    Text(affiliationLine).font(.system(size: 14, weight: .bold))
                    Text("(\(person.displayName(showFullName: showFullName)))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                } else {
                    Text(person.displayName(showFullName: showFullName))
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.top, 4)

            Text(person.note).font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 2)

            if !overlap.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(overlap) { overlapDay in
                        HStack {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(dateLabel(overlapDay.day)).font(.system(size: 12)).foregroundStyle(Theme.amber)
                                Text(" \(airportLabel(overlapDay.location)) — \(laterTime(overlapDay.myFrom, overlapDay.otherFrom))以降どちらも動けます")
                                    .font(.system(size: 12)).foregroundStyle(Theme.text)
                            }
                            Spacer()
                            if offerStatus == nil, let onOffer {
                                Button("🍻 誘う") { onOffer(person, overlapDay, autoAccept) }
                                    .buttonStyle(BoardOutlineButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.top, 8)
            }

            switch offerStatus {
            case .accepted:
                Text("マッチ成立").font(.system(size: 12)).foregroundStyle(Theme.green).padding(.top, 8)
            case .pending:
                Text("誘い送信済み(相手の承諾待ち)").font(.system(size: 12)).foregroundStyle(Theme.amberDim).padding(.top, 8)
                if let offerID, let onCancelOffer {
                    Button("誘いをキャンセル") { onCancelOffer(offerID) }
                        .buttonStyle(BoardChromeButtonStyle())
                        .padding(.top, 6)
                }
            case .expired:
                Text("誘いの有効期限が切れました").font(.system(size: 12)).foregroundStyle(Theme.faint).padding(.top, 8)
            case .cancelled:
                Text("誘いをキャンセルしました").font(.system(size: 12)).foregroundStyle(Theme.faint).padding(.top, 8)
            case nil:
                if autoAcceptOfferFeatureEnabled, onOffer != nil {
                    Toggle(isOn: $autoAccept) {
                        Text("この誘いは自動承諾でOK(承諾ステップを省略)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    .toggleStyle(.checkbox)
                    .padding(.top, 8)
                }

                if let onPass {
                    Button("見送る") { onPass(person) }
                        .buttonStyle(BoardChromeButtonStyle())
                        .padding(.top, 6)
                }
            }
        }
        .padding(.bottom, 10)
        .sheet(isPresented: $showingReportSheet) {
            ReportBlockSheet(
                person: person,
                onSubmitReport: { reason, details in await onReport(person, reason, details) },
                onBlock: { await onBlock(person) }
            )
        }
    }
}
