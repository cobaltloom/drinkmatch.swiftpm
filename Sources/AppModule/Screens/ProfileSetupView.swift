import SwiftUI

/// First-run onboarding: pick a role, base airport, name, and how that name
/// should appear to strangers later.
struct ProfileSetupView: View {
    var onDone: (UserProfile, Bool) -> Void

    @State private var role = Roles.all[2].code // CA
    @State private var base = ""
    @State private var fullName = ""
    @State private var displayMode: DisplayMode = .initials
    @State private var nickname = ""
    @State private var ageConfirmed = false

    private var trimmedFullName: String { fullName.trimmingCharacters(in: .whitespaces) }
    private var trimmedNickname: String { nickname.trimmingCharacters(in: .whitespaces) }
    private var previewInitials: String { initials(from: fullName) }

    private var previewName: String {
        displayMode == .nickname
            ? (trimmedNickname.isEmpty ? "(ニックネーム未入力)" : trimmedNickname)
            : (previewInitials.isEmpty ? "(お名前未入力)" : previewInitials)
    }

    private var canSubmit: Bool {
        !base.isEmpty
            && (displayMode == .nickname ? !trimmedNickname.isEmpty : !trimmedFullName.isEmpty)
            && ageConfirmed
    }

    var body: some View {
        BoardScreenContainer {
            VStack(spacing: 4) {
                Text("CREW BOARD").splitFlap(28, weight: .bold).foregroundStyle(Theme.amber)
                Text("ステイ先でご飯")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)

            BoardCard {
                Text("職種").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.bottom, 6)
                FlowLayout(spacing: 8) {
                    ForEach(Roles.all) { roleOption in
                        Button(roleOption.label) { role = roleOption.code }
                            .font(.system(size: 13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(role == roleOption.code ? Theme.amber : Theme.text)
                            .background(role == roleOption.code ? Theme.amberBackground : Theme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(role == roleOption.code ? Theme.amber : Theme.fieldBorder)
                            )
                    }
                }

                Text("拠点空港").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 16).padding(.bottom, 6)
                AirportAutocompleteField(code: $base)

                Text("お名前").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 16).padding(.bottom, 6)
                TextField("例: YOSUKE TANAKA", text: $fullName)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                Text("知り合いにはこのお名前が表示されます。新しい人を探す機能ではイニシャル生成にのみ使用され、直接は表示されません。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("新しい人を探す機能での表示名").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Picker("表示名", selection: $displayMode) {
                        Text("イニシャル").tag(DisplayMode.initials)
                        Text("ニックネーム").tag(DisplayMode.nickname)
                    }
                    .pickerStyle(.segmented)

                    if displayMode == .nickname {
                        TextField("例: そらまめ", text: $nickname)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    }

                    HStack(spacing: 0) {
                        Text("プレビュー: ").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        Text(previewName).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.amber)
                    }
                }
                .padding(12)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
                .padding(.top, 18)

                Toggle(isOn: $ageConfirmed) {
                    Text("私は20歳以上であり、本アプリが飲酒を伴う交流の場のマッチングを目的としていることを理解しています。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 18)

                Button("プロフィールを作成して始める") {
                    let profile = UserProfile(role: role, base: base, fullName: fullName, displayMode: displayMode, nickname: nickname)
                    onDone(profile, ageConfirmed)
                }
                .buttonStyle(BoardButtonStyle(isDisabled: !canSubmit))
                .disabled(!canSubmit)
                .padding(.top, 12)

                Text("※知り合いマッチングは今すぐ利用できます。「新しい人と探す」機能を使う際に会社メールでの本人確認が必要になります。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
