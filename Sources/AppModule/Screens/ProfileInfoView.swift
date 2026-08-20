import SwiftUI

/// Account/profile summary, reachable from MainView's overflow menu —
/// shows which email address the user is signed in with, and lets them
/// change their name (unrestricted — see DrinkMatchStore.updateFullName)
/// and role/airline/base (rate-limited server-side, see
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

    @State private var isEditingName = false
    @State private var editFullName = ""
    @State private var isNameSubmitting = false
    @State private var nameEditMessage: String?

    @State private var isEditingContactInfo = false
    @State private var editContactInfo = ""
    @State private var isContactInfoSubmitting = false
    @State private var contactInfoEditMessage: String?

    @State private var isEditingBirthYear = false
    @State private var editBirthYear: Int?
    @State private var isBirthYearSubmitting = false
    @State private var birthYearEditMessage: String?

    private static let birthYearOptions: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 70)...(currentYear - 18)).reversed()
    }()

    private var canEditIdentity: Bool { store.profile?.canEditIdentity ?? true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("プロフィール").splitFlap(16, weight: .bold).foregroundStyle(Theme.amber)

                infoRow(label: "サインイン中のメールアドレス", value: store.authEmail ?? "不明")

                nameSection
                contactInfoSection
                birthYearSection
                identitySection

                infoRow(label: "本人確認", value: store.isVerified ? "確認済み" : "未確認")
                infoRow(label: "新しい人を探す機能", value: store.isSubscribed ? "利用中" : "未加入")

                HStack(spacing: 16) {
                    Link("利用規約", destination: termsOfUseURL)
                    Link("プライバシーポリシー", destination: privacyPolicyURL)
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)

                Button("閉じる") { dismiss() }
                    .buttonStyle(BoardChromeButtonStyle())
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingName {
                Text("お名前").font(.system(size: 11)).foregroundStyle(Theme.muted)
                TextField("例: YOSUKE TANAKA", text: $editFullName)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                HStack(spacing: 12) {
                    Button("保存") { Task { await submitFullName() } }
                        .buttonStyle(BoardButtonStyle(isDisabled: isNameSubmitting))
                        .disabled(isNameSubmitting)
                    Button("キャンセル") { isEditingName = false }
                        .buttonStyle(BoardOutlineButtonStyle())
                        .disabled(isNameSubmitting)
                }
                .padding(.top, 4)

                if let nameEditMessage {
                    Text(nameEditMessage).font(.system(size: 12)).foregroundStyle(Theme.red)
                }
            } else {
                infoRow(label: "お名前", value: store.profile?.fullName ?? "未登録")
                Button("変更する") { startEditingName() }
                    .buttonStyle(BoardOutlineButtonStyle())
            }
        }
    }

    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingContactInfo {
                Text("連絡先(LINE ID・電話番号など)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                TextField("例: LINE ID: xxxxx", text: $editContactInfo)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                HStack(spacing: 12) {
                    Button("保存") { Task { await submitContactInfo() } }
                        .buttonStyle(BoardButtonStyle(isDisabled: isContactInfoSubmitting))
                        .disabled(isContactInfoSubmitting)
                    Button("キャンセル") { isEditingContactInfo = false }
                        .buttonStyle(BoardOutlineButtonStyle())
                        .disabled(isContactInfoSubmitting)
                }
                .padding(.top, 4)

                if let contactInfoEditMessage {
                    Text(contactInfoEditMessage).font(.system(size: 12)).foregroundStyle(Theme.red)
                }

                Text("マッチが成立した相手にのみ表示されます。誘いを送っただけの段階では表示されません。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
            } else {
                infoRow(label: "連絡先(マッチ成立後に相手へ表示)", value: store.profile?.contactInfo ?? "未登録")
                Button("変更する") { startEditingContactInfo() }
                    .buttonStyle(BoardOutlineButtonStyle())
            }
        }
    }

    private var birthYearSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingBirthYear {
                Text("生まれ年(任意・年齢が近い人を探すフィルターに使われます)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)

                Menu {
                    Button("未設定") { editBirthYear = nil }
                    ForEach(Self.birthYearOptions, id: \.self) { year in
                        Button("\(String(year))年") { editBirthYear = year }
                    }
                } label: {
                    HStack {
                        Text(editBirthYear.map { "\(String($0))年" } ?? "未設定")
                            .font(.system(size: 14))
                            .foregroundStyle(editBirthYear == nil ? Theme.faint : Theme.text)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                }
                .menuStyle(.borderlessButton)

                HStack(spacing: 12) {
                    Button("保存") { Task { await submitBirthYear() } }
                        .buttonStyle(BoardButtonStyle(isDisabled: isBirthYearSubmitting))
                        .disabled(isBirthYearSubmitting)
                    Button("キャンセル") { isEditingBirthYear = false }
                        .buttonStyle(BoardOutlineButtonStyle())
                        .disabled(isBirthYearSubmitting)
                }
                .padding(.top, 4)

                if let birthYearEditMessage {
                    Text(birthYearEditMessage).font(.system(size: 12)).foregroundStyle(Theme.red)
                }
            } else {
                infoRow(label: "生まれ年", value: store.profile?.birthYear.map { "\($0)年" } ?? "未設定")
                if store.profile?.canEditBirthYear ?? true {
                    Button("変更する") { startEditingBirthYear() }
                        .buttonStyle(BoardOutlineButtonStyle())
                    Text("生まれ年を変更できるのは合計2回までです(残り\(2 - (store.profile?.birthYearChangeCount ?? 0))回)。")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                } else {
                    Text("生まれ年は変更回数の上限(2回)に達しました。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
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

    private func startEditingName() {
        editFullName = store.profile?.fullName ?? ""
        nameEditMessage = nil
        isEditingName = true
    }

    private func submitFullName() async {
        isNameSubmitting = true
        defer { isNameSubmitting = false }
        nameEditMessage = await store.updateFullName(editFullName)
        if nameEditMessage == nil {
            isEditingName = false
        }
    }

    private func startEditingContactInfo() {
        editContactInfo = store.profile?.contactInfo ?? ""
        contactInfoEditMessage = nil
        isEditingContactInfo = true
    }

    private func submitContactInfo() async {
        isContactInfoSubmitting = true
        defer { isContactInfoSubmitting = false }
        contactInfoEditMessage = await store.updateContactInfo(editContactInfo)
        if contactInfoEditMessage == nil {
            isEditingContactInfo = false
        }
    }

    private func startEditingBirthYear() {
        editBirthYear = store.profile?.birthYear
        birthYearEditMessage = nil
        isEditingBirthYear = true
    }

    private func submitBirthYear() async {
        isBirthYearSubmitting = true
        defer { isBirthYearSubmitting = false }
        birthYearEditMessage = await store.updateBirthYear(editBirthYear)
        if birthYearEditMessage == nil {
            isEditingBirthYear = false
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
