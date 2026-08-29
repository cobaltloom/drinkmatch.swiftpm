import SwiftUI
import UIKit

/// Detail pane for one persistent group: roster, invite-code sharing,
/// inviting a friend directly (pending their acceptance), leaving, and the
/// day+airport schedule-overlap ranking — the actual "誰と誰の予定が合うか"
/// feature this screen exists for.
struct MemberGroupDetailView: View {
    var store: DrinkMatchStore
    var group: MemberGroup

    @State private var members: [MemberGroupPerson] = []
    @State private var ranking: [MemberGroupScheduleMatch] = []
    @State private var isLoadingRanking = true
    @State private var selectedFriendID: UUID?
    @State private var inviteMessage: String?
    @State private var didCopyCode = false
    @State private var membersExpanded = false

    private var invitableFriends: [Person] {
        let memberIDs = Set(members.map(\.userID))
        return store.friends.filter { !memberIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.name).font(.system(size: 14, weight: .bold))
                Spacer()
                Button("グループを抜ける", role: .destructive) { Task { await store.leaveMemberGroup(group.id) } }
                    .buttonStyle(BoardChromeButtonStyle())
            }

            HStack(spacing: 8) {
                Text("招待コード:").font(.system(size: 11)).foregroundStyle(Theme.muted)
                Text(group.inviteCode)
                    .splitFlap(14, weight: .bold)
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Button(didCopyCode ? "コピーしました" : "コピー") { copyCode() }
                    .buttonStyle(BoardOutlineButtonStyle())
            }
            Text("このコードを伝えると、相手は承諾なしですぐグループに参加できます。")
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)

            DisclosureGroup(isExpanded: $membersExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(members) { member in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Roles.label(for: member.role)).splitFlap(11).foregroundStyle(Theme.amber)
                            Text(member.fullName).font(.system(size: 12))
                            if !member.airline.isEmpty {
                                Text("(\(airlineLabel(member.airline)))").font(.system(size: 10)).foregroundStyle(Theme.faint)
                            }
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("メンバー (\(members.count))").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .tint(Theme.muted)

            if !invitableFriends.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("知り合いを招待").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        Picker("", selection: $selectedFriendID) {
                            Text("選択してください").tag(nil as UUID?)
                            ForEach(invitableFriends) { friend in
                                Text(friend.fullName ?? friend.name).tag(friend.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.text)
                        Button("招待") { Task { await invite() } }
                            .buttonStyle(BoardOutlineButtonStyle())
                            .disabled(selectedFriendID == nil)
                    }
                    if let inviteMessage {
                        Text(inviteMessage).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("予定が合う日程").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                if isLoadingRanking {
                    ProgressView().tint(Theme.amber)
                } else if ranking.isEmpty {
                    Text("まだ予定が重なる日がありません。").font(.system(size: 12)).foregroundStyle(Theme.faint)
                } else {
                    ForEach(ranking) { match in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(dateLabel(match.day)) — \(airportLabel(match.location))")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Text("\(match.memberNames.count)人").font(.system(size: 12)).foregroundStyle(Theme.amber)
                            }
                            Text(match.memberNames.joined(separator: ", "))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .task(id: group.id) {
            members = await store.loadMemberGroupMembers(group.id)
            isLoadingRanking = true
            ranking = await store.loadMemberGroupScheduleRanking(group.id)
            isLoadingRanking = false
        }
    }

    private func invite() async {
        guard let selectedFriendID else { return }
        if let error = await store.inviteToMemberGroup(groupID: group.id, friendUserID: selectedFriendID) {
            inviteMessage = error
        } else {
            inviteMessage = "招待を送信しました。相手が承諾するとメンバーに追加されます。"
        }
        self.selectedFriendID = nil
    }

    private func copyCode() {
        UIPasteboard.general.string = group.inviteCode
        didCopyCode = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            didCopyCode = false
        }
    }
}
