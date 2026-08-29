import SwiftUI

/// "グループ" — persistent groups for group-wide schedule matching, as
/// opposed to the 1-on-1 friends/strangers tabs (see MainView's
/// contactMode switcher). Create or join a group, respond to invites, and
/// pick a group in the sidebar to see its roster and schedule-overlap
/// ranking (MemberGroupDetailView) — same master-detail layout as
/// MatchesView.
struct GroupsTabView: View {
    var store: DrinkMatchStore

    @State private var newGroupName = ""
    @State private var joinCode = ""
    @State private var errorMessage = ""
    @State private var statusMessage = ""
    @State private var selectedGroupID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BoardCard {
                Text("グループを作成").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.bottom, 6)
                HStack(spacing: 8) {
                    TextField("グループ名(例: 同期会)", text: $newGroupName)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    Button("作成") { Task { await createGroup() } }
                        .buttonStyle(BoardOutlineButtonStyle())
                }
            }

            BoardCard {
                Text("招待コードでグループに参加").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.bottom, 6)
                HStack(spacing: 8) {
                    TextField("例: A1B2C3D4", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    Button("参加") { Task { await join() } }
                        .buttonStyle(BoardOutlineButtonStyle())
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 11)).foregroundStyle(Theme.red).padding(.top, 6)
                } else if !statusMessage.isEmpty {
                    Text(statusMessage).font(.system(size: 11)).foregroundStyle(Theme.green).padding(.top, 6)
                }
            }

            IncomingMemberGroupInvitesView(
                invites: store.incomingMemberGroupInvites,
                onRespond: { invite, accept in Task { await store.respondToMemberGroupInvite(invite.id, accept: accept) } }
            )

            if store.memberGroups.isEmpty {
                Text("まだグループがありません。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
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
            await store.loadMemberGroups()
            await store.loadIncomingMemberGroupInvites()
            await store.loadFriends()
            if selectedGroupID == nil { selectedGroupID = store.memberGroups.first?.id }
        }
        .onChange(of: store.memberGroups) { _, groups in
            if !groups.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = groups.first?.id
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 6) {
            ForEach(store.memberGroups) { group in
                let isActive = group.id == selectedGroupID
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.system(size: 12, weight: .bold))
                    Text("\(group.memberCount)人").font(.system(size: 11)).foregroundStyle(Theme.faint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isActive ? Theme.card : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(isActive ? Theme.amber : .clear))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .onTapGesture { selectedGroupID = group.id }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let group = store.memberGroups.first(where: { $0.id == selectedGroupID }) {
            MemberGroupDetailView(store: store, group: group)
        } else {
            EmptyView()
        }
    }

    private func createGroup() async {
        if let error = await store.createMemberGroup(name: newGroupName) {
            errorMessage = error
            statusMessage = ""
        } else {
            newGroupName = ""
            errorMessage = ""
            statusMessage = "グループを作成しました。"
        }
    }

    private func join() async {
        if let error = await store.joinMemberGroup(byCode: joinCode) {
            errorMessage = error
            statusMessage = ""
        } else {
            joinCode = ""
            errorMessage = ""
            statusMessage = "グループに参加しました。"
        }
    }
}
