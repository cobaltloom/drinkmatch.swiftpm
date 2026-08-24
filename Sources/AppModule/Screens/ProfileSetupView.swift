import SwiftUI

/// First-run onboarding: pick a role, base airport, and name.
struct ProfileSetupView: View {
    var onDone: (UserProfile, Bool) -> Void

    @State private var role = Roles.all[2].code // CA
    @State private var base = ""
    @State private var fullName = ""
    @State private var ageConfirmed = false

    private var trimmedFullName: String { fullName.trimmingCharacters(in: .whitespaces) }

    private var canSubmit: Bool {
        !base.isEmpty && !trimmedFullName.isEmpty && ageConfirmed
    }

    var body: some View {
        BoardScreenContainer {
            VStack(spacing: 4) {
                Text("Crew Board").splitFlap(28, weight: .bold).foregroundStyle(Theme.amber)
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
                Text("知り合いにはこのお名前が表示されます。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $ageConfirmed) {
                    Text("私は20歳以上であり、本アプリが飲酒を伴う交流の場のマッチングを目的としていることを理解しています。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 18)

                Button("プロフィールを作成して始める") {
                    let profile = UserProfile(role: role, base: base, fullName: fullName, displayMode: .initials, nickname: "")
                    onDone(profile, ageConfirmed)
                }
                .buttonStyle(BoardButtonStyle(isDisabled: !canSubmit))
                .disabled(!canSubmit)
                .padding(.top, 12)
            }
        }
    }
}
