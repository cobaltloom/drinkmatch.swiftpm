import SwiftUI

/// Account/profile summary, reachable from MainView's overflow menu —
/// shows which email address the user is signed in with, and lets them
/// change role/airline/base (rate-limited server-side, see
/// DrinkMatchStore.updateIdentity).
struct ProfileInfoView: View {
    var store: DrinkMatchStore

    @Environment(\.dismiss) private var dismiss

    @State private var isEditingIdentity = false
    @State private var editRole = ""
    @State private var editAirline = ""
    @State private var editBase = ""
    @State private var isSubmitting = false
    @State private var editMessage: String?

    private var canEditIdentity: Bool { store.profile?.canEditIdentity ?? true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("プロフィール").splitFlap(16, weight: .bold).foregroundStyle(Theme.amber)

                infoRow(label: "サインイン中のメールアドレス", value: store.authEmail ?? "不明")

                identitySection

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

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingIdentity {
                Text("職種").font(.system(size: 11)).foregroundStyle(Theme.muted)
                FlowLayout(spacing: 8) {
                    ForEach(Roles.all) { roleOption in
                        Button(roleOption.label) { editRole = roleOption.code }
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(editRole == roleOption.code ? Theme.amber : Theme.text)
                            .background(editRole == roleOption.code ? Theme.amberBackground : Theme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(editRole == roleOption.code ? Theme.amber : Theme.fieldBorder)
                            )
                    }
                }

                Text("会社").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.top, 8)
                AirlineAutocompleteField(code: $editAirline)

                Text("拠点空港").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.top, 8)
                AirportAutocompleteField(code: $editBase)

                HStack(spacing: 12) {
                    Button("保存") { Task { await submitIdentity() } }
                        .buttonStyle(BoardButtonStyle(isDisabled: isSubmitting || editBase.isEmpty))
                        .disabled(isSubmitting || editBase.isEmpty)
                    Button("キャンセル") { isEditingIdentity = false }
                        .buttonStyle(BoardOutlineButtonStyle())
                        .disabled(isSubmitting)
                }
                .padding(.top, 4)

                if let editMessage {
                    Text(editMessage).font(.system(size: 12)).foregroundStyle(Theme.red)
                }

                Text("職種・会社・拠点空港は30日に1回まで変更できます。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
            } else {
                infoRow(label: "職種", value: Roles.label(for: store.profile?.role ?? ""))
                infoRow(label: "会社", value: (store.profile?.airline).flatMap { $0.isEmpty ? nil : airlineLabel($0) } ?? "未登録")
                infoRow(label: "拠点空港", value: (store.profile?.base).flatMap { $0.isEmpty ? nil : airportLabel($0) } ?? "未登録")

                if canEditIdentity {
                    Button("変更する") { startEditingIdentity() }
                        .buttonStyle(BoardOutlineButtonStyle())
                } else if let profile = store.profile {
                    Text("次に変更できるのは \(Self.dateFormatter.string(from: profile.nextIdentityEditDate)) です。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
    }

    private func startEditingIdentity() {
        editRole = store.profile?.role ?? Roles.all[0].code
        editAirline = store.profile?.airline ?? ""
        editBase = store.profile?.base ?? ""
        editMessage = nil
        isEditingIdentity = true
    }

    private func submitIdentity() async {
        isSubmitting = true
        defer { isSubmitting = false }
        editMessage = await store.updateIdentity(role: editRole, airline: editAirline, base: editBase)
        if editMessage == nil {
            isEditingIdentity = false
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

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
