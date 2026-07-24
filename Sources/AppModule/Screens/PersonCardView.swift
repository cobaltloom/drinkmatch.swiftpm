import SwiftUI

/// A candidate row for 1:1 offers — shows overlap days/times and lets the
/// user send an offer (optionally auto-accepting), pass, or see the current
/// offer status.
struct PersonCardView: View {
    var person: Person
    var mySchedule: [StayEntry]
    var offerStatus: OfferStatus?
    var showFullName: Bool
    var defaultAutoAccept: Bool
    var viewerFriendID: Int?
    var onOffer: (Person, Bool) -> Void
    var onPass: (Person) -> Void

    @State private var autoAccept: Bool

    init(person: Person, mySchedule: [StayEntry], offerStatus: OfferStatus?, showFullName: Bool,
         defaultAutoAccept: Bool, viewerFriendID: Int? = nil,
         onOffer: @escaping (Person, Bool) -> Void, onPass: @escaping (Person) -> Void) {
        self.person = person
        self.mySchedule = mySchedule
        self.offerStatus = offerStatus
        self.showFullName = showFullName
        self.defaultAutoAccept = defaultAutoAccept
        self.viewerFriendID = viewerFriendID
        self.onOffer = onOffer
        self.onPass = onPass
        _autoAccept = State(initialValue: defaultAutoAccept)
    }

    private var overlap: [StayOverlap] {
        matchStays(mine: mySchedule, theirs: person.stays, viewerPersonID: viewerFriendID)
    }

    var body: some View {
        BoardCard {
            HStack(alignment: .firstTextBaseline) {
                Text(person.role).splitFlap(13, weight: .bold).foregroundStyle(Theme.amber)
                Spacer()
                Text(overlap.isEmpty ? "共通ステイ先なし" : "同じステイ先あり")
                    .font(.system(size: 11))
                    .foregroundStyle(overlap.isEmpty ? Theme.red : Theme.green)
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
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(overlap) { o in
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(fmtDate(o.day)).font(.system(size: 12)).foregroundStyle(Theme.amber)
                            Text(" \(airportLabel(o.location)) — \(laterTime(o.myFrom, o.otherFrom))以降どちらも動けます")
                                .font(.system(size: 12)).foregroundStyle(Theme.text)
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
            case nil:
                Toggle(isOn: $autoAccept) {
                    Text("この誘いは自動承諾でOK(承諾ステップを省略)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 8)

                HStack(spacing: 8) {
                    Button("🍻 ステイ先で誘う") { onOffer(person, autoAccept) }
                        .buttonStyle(BoardOutlineButtonStyle(isDisabled: overlap.isEmpty))
                        .disabled(overlap.isEmpty)
                    Button("見送る") { onPass(person) }
                        .buttonStyle(BoardChromeButtonStyle())
                }
                .padding(.top, 6)
            }
        }
        .padding(.bottom, 10)
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
