import SwiftUI

/// Read-only account/profile summary, reachable from MainView's overflow
/// menu — mainly so users can check which email address they're signed in
/// with.
struct ProfileInfoView: View {
    var store: DrinkMatchStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("プロフィール").splitFlap(16, weight: .bold).foregroundStyle(Theme.amber)

                infoRow(label: "サインイン中のメールアドレス", value: store.authEmail ?? "不明")
                infoRow(label: "職種", value: Roles.label(for: store.profile?.role ?? ""))
                infoRow(label: "会社", value: (store.profile?.airline).flatMap { $0.isEmpty ? nil : airlineLabel($0) } ?? "未登録")
                infoRow(label: "拠点空港", value: (store.profile?.base).flatMap { $0.isEmpty ? nil : airportLabel($0) } ?? "未登録")
                infoRow(label: "本人確認", value: store.isVerified ? "確認済み" : "未確認")
                infoRow(label: "新しい人を探す機能", value: store.isSubscribed ? "利用中" : "未加入")

                Button("閉じる") { dismiss() }
                    .buttonStyle(BoardChromeButtonStyle())
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 14)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
    }
}
