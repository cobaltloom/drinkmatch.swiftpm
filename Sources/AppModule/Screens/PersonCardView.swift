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
    var showFullName: Bool
    var defaultAutoAccept: Bool
    /// The backend pins an offer to one specific day + airport at creation
    /// time (handoff doc §7's OFFERS.day/airport_code), so — unlike the
    /// mock-data prototype's single ambiguous "誘う" button — offering is
    /// per overlapping day, not per person.
    var onOffer: (Person, StayOverlap, Bool) -> Void
    var onPass: (Person) -> Void
    var onReport: (Person, ReportReason, String) async -> String?
    var onBlock: (Person) async -> Void

    @State private var autoAccept: Bool
    @State private var showingReportSheet = false

    init(person: Person, overlap: [StayOverlap], offerStatus: OfferStatus?, showFullName: Bool,
         defaultAutoAccept: Bool,
         onOffer: @escaping (Person, StayOverlap, Bool) -> Void, onPass: @escaping (Person) -> Void,
         onReport: @escaping (Person, ReportReason, String) async -> String?, onBlock: @escaping (Person) async -> Void) {
        self.person = person
        self.overlap = overlap
        self.offerStatus = offerStatus
        self.showFullName = showFullName
        self.defaultAutoAccept = defaultAutoAccept
        self.onOffer = onOffer
        self.onPass = onPass
        self.onReport = onReport
        self.onBlock = onBlock
        _autoAccept = State(initialValue: defaultAutoAccept)
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
                Text("\(person.airline) / \(person.base)").font(.system(size: 14, weight: .bold))
                Text("(\(person.displayName(showFullName: showFullName)))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.top, 4)

            Text(person.note).font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 2)

            if !overlap.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(overlap) { o in
                        HStack {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(fmtDate(o.day)).font(.system(size: 12)).foregroundStyle(Theme.amber)
                                Text(" \(airportLabel(o.location)) — \(laterTime(o.myFrom, o.otherFrom))以降どちらも動けます")
                                    .font(.system(size: 12)).foregroundStyle(Theme.text)
                            }
                            Spacer()
                            if offerStatus == nil {
                                Button("🍻 誘う") { onOffer(person, o, autoAccept) }
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
            case .expired:
                Text("誘いの有効期限が切れました").font(.system(size: 12)).foregroundStyle(Theme.faint).padding(.top, 8)
            case nil:
                Toggle(isOn: $autoAccept) {
                    Text("この誘いは自動承諾でOK(承諾ステップを省略)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 8)

                Button("見送る") { onPass(person) }
                    .buttonStyle(BoardChromeButtonStyle())
                    .padding(.top, 6)
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

/// Minimal checkbox-style toggle so labels read left-to-right like a form
/// checkbox instead of a trailing iOS switch.
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Theme.amber : Theme.faint)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
