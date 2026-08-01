import SwiftUI

/// Reachable from MainView's overflow menu — lists users this account has
/// blocked and lets them be unblocked (see AppStore.blockedUsers /
/// unblockUser). Blocking is per-account, so this reads/writes the
/// `blocks` table via `list_blocked_users()` / `unblock_user()`.
struct BlockedUsersView: View {
    var store: AppStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("ブロック中のユーザー").splitFlap(16, weight: .bold).foregroundStyle(Theme.amber)
                    Spacer()
                    Button("閉じる") { dismiss() }
                        .buttonStyle(BoardChromeButtonStyle())
                }

                if store.blockedUsers.isEmpty {
                    Text("ブロック中のユーザーはいません。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(store.blockedUsers) { user in
                        HStack {
                            Text(user.displayName).font(.system(size: 13))
                            Spacer()
                            Button("ブロック解除") { Task { await store.unblockUser(user.userID) } }
                                .buttonStyle(BoardOutlineButtonStyle())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .task { await store.loadBlockedUsers() }
    }
}
