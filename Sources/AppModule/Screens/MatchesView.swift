import SwiftUI

/// "ARRIVALS" — the match list: every active 1:1 offer and group offer,
/// with a detail pane for accepting / sending the meetup proposal.
struct MatchesView: View {
    var store: AppStore

    private enum Entry: Hashable {
        case individual(Int)
        case group(String)
    }

    @State private var activeEntry: Entry?
    @State private var composeTime = date(fromTimeString: "19:30")
    @State private var composePlace = ""

    private var entries: [Entry] {
        store.matches.map { .individual($0.id) } + store.groups.map { .group($0.id) }
    }

    var body: some View {
        BoardScreenContainer {
            HStack(alignment: .firstTextBaseline) {
                Text("ARRIVALS — マッチ一覧").splitFlap(20, weight: .bold).foregroundStyle(Theme.amber)
                Spacer()
                Button("戻る") { store.screen = .main }
                    .buttonStyle(BoardChromeButtonStyle())
            }
            .padding(.bottom, 12)

            if entries.isEmpty {
                Text("まだマッチがありません。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    sidebar
                        .frame(width: 130)
                    detail
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .onAppear { if activeEntry == nil { activeEntry = entries.first } }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 6) {
            ForEach(entries, id: \.self) { entry in
                sidebarRow(for: entry)
                    .onTapGesture { activeEntry = entry }
            }
        }
    }

    @ViewBuilder
    private func sidebarRow(for entry: Entry) -> some View {
        let isActive = activeEntry == entry
        Group {
            switch entry {
            case .individual(let id):
                if let match = store.matches.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.person.fullName ?? match.person.name).font(.system(size: 12, weight: .bold))
                        Text(match.status == .accepted ? "マッチ成立" : "承諾待ち")
                            .font(.system(size: 11))
                            .foregroundStyle(match.status == .accepted ? Theme.green : Theme.amberDim)
                    }
                }
            case .group(let id):
                if let group = store.groups.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("👥 \(fmtDate(group.day)) \(airportLabel(group.location))")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(group.acceptedCount)/\(group.members.count) 承諾")
                            .font(.system(size: 11))
                            .foregroundStyle(group.acceptedCount > 0 ? Theme.green : Theme.amberDim)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Theme.card : Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(isActive ? Theme.amber : .clear))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Detail pane

    @ViewBuilder
    private var detail: some View {
        switch activeEntry {
        case .individual(let id):
            if let match = store.matches.first(where: { $0.id == id }) {
                individualDetail(match)
            }
        case .group(let id):
            if let group = store.groups.first(where: { $0.id == id }) {
                GroupDetailView(
                    group: group,
                    onAcceptMember: { store.acceptGroupMember(groupID: group.id, memberID: $0) },
                    composeTime: $composeTime,
                    composePlace: $composePlace,
                    onSendProposal: { store.sendGroupProposal(groupID: group.id, time: timeString(from: composeTime), place: composePlace) }
                )
            }
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func individualDetail(_ match: MatchedPerson) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(match.person.fullName ?? match.person.name).font(.system(size: 14, weight: .bold))
                Text("(\(match.person.airline) / \(match.person.base))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }

            if match.status != .accepted {
                VStack(alignment: .leading, spacing: 10) {
                    Text("この誘いは自動承諾を選ばなかったため、相手が承諾するまで集合案は送れません。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("(デモ)相手が承諾したことにする") { store.simulateAccept(personID: match.id) }
                        .buttonStyle(BoardOutlineButtonStyle())
                }
                .padding(14)
                .background(Theme.field)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("相手のステイ先(緑の日付をタップして集合案を送信)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)

                if let sent = match.sentProposal {
                    SentProposalSummary(proposal: sent, footnote: nil)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ReadOnlyStayCalendar(stays: match.person.stays) { entry in
                            store.sendProposal(
                                personID: match.id,
                                day: entry.day,
                                location: entry.location,
                                time: timeString(from: composeTime),
                                place: composePlace
                            )
                        }
                        DatePicker("", selection: $composeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Theme.amber)
                        TextField("お店(例: 国際通り 居酒屋)", text: $composePlace)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                        Text("緑の日付が相手のステイ日です。タップすると集合案を送信します。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(12)
                    .background(Theme.field)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
