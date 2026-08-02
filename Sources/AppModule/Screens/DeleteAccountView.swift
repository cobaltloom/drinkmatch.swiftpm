import SwiftUI

/// Confirmation flow for AppStore.deleteAccount(), reachable from MainView's
/// overflow menu — App Store Review Guideline 5.1.1(v) requires account
/// deletion to be possible from within the app itself, not just by
/// contacting support.
struct DeleteAccountView: View {
    var store: AppStore

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("アカウントを削除").splitFlap(16, weight: .bold).foregroundStyle(Theme.red)

                Text("削除すると、プロフィール・スケジュール・知り合い・マッチ・通知など、このアカウントに関するすべてのデータが完全に削除されます。この操作は取り消せません。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 12)).foregroundStyle(Theme.red)
                }

                Button {
                    Task { await confirmDelete() }
                } label: {
                    Text(isDeleting ? "削除中…" : "完全に削除する")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Theme.text)
                        .background(Theme.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .opacity(isDeleting ? 0.7 : 1)
                }
                .disabled(isDeleting)

                Button("キャンセル") { dismiss() }
                    .buttonStyle(BoardChromeButtonStyle())
                    .disabled(isDeleting)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .interactiveDismissDisabled(isDeleting)
    }

    private func confirmDelete() async {
        isDeleting = true
        errorMessage = ""
        if let error = await store.deleteAccount() {
            errorMessage = error
            isDeleting = false
        }
        // On success the store signs itself out and resets state, so
        // RootView switches to SignInView and this sheet's presenter
        // (MainView) is gone along with it — no explicit dismiss() needed.
    }
}
