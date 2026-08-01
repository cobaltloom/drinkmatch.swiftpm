import SwiftUI

/// "ARRIVALS" — the match list: every active 1:1 offer and group offer,
/// with a detail pane for accepting / sending the meetup proposal.
struct MatchesView: View {
    var store: AppStore

    private enum Entry: Hashable {
        case individual(UUID)
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
        .task {
            await store.loadMatches()
            if activeEntry == nil { activeEntry = entries.first }
        }
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
                        Text(statusLabel(for: match))
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

    private func statusLabel(for match: MatchedPerson) -> String {
        switch match.status {
        case .accepted: return "マッチ成立"
        case .expired: return "期限切れ"
        case .pending: return match.isIncoming ? "承諾待ち(あなた)" : "承諾待ち(相手)"
        }
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
                    myUserID: store.authUserID,
                    onAcceptOwnMembership: { Task { await store.acceptGroupMembership(groupOfferID: group.id) } },
                    composeTime: $composeTime,
                    composePlace: $composePlace,
                    onSendProposal: {
                        Task { await store.sendGroupProposal(groupOfferID: group.id, time: timeString(from: composeTime), place: composePlace) }
                    }
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

            if match.status == .expired {
                Text("この誘いは有効期限が切れました。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.field)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if match.status != .accepted {
                VStack(alignment: .leading, spacing: 10) {
                    if match.isIncoming {
                        Text("\(match.person.fullName ?? match.person.name)さんから誘いが届いています。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("承諾する") { Task { await store.acceptOffer(offerID: match.offerID) } }
                            .buttonStyle(BoardButtonStyle())
                    } else {
                        Text("この誘いは自動承諾を選ばなかったため、相手が承諾するまで集合案は送れません。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                            Task {
                                await store.sendProposal(
                                    offerID: match.offerID,
                                    day: entry.day,
                                    location: entry.location,
                                    time: timeString(from: composeTime),
                                    place: composePlace
                                )
                            }
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
