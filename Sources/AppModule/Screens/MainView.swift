import SwiftUI

/// The home screen: profile summary, mode switcher (friends vs. strangers),
/// and the active tab's candidate list.
struct MainView: View {
    @Bindable var store: AppStore

    private var profileBinding: Binding<UserProfile> {
        Binding(get: { store.profile ?? UserProfile(role: Roles.all[0].code, base: Bases.all[0], fullName: "", displayMode: .initials, nickname: "") },
                set: { store.profile = $0 })
    }

    private var myReferralCodePairs: [(code: String, used: Bool)] {
        store.myReferralCodes.map { code in (code: code, used: store.referralCodes[code]?.used ?? false) }
    }

    private var scheduleSummary: String {
        store.mySchedule.isEmpty
            ? "未設定"
            : store.mySchedule.map { "\(fmtDate($0.day))\(airportLabel($0.location))" }.joined(separator: ", ")
    }

    var body: some View {
        BoardScreenContainer {
            HStack(alignment: .firstTextBaseline) {
                Text("CREW BOARD").splitFlap(20, weight: .bold).foregroundStyle(Theme.amber)
                Spacer()
                HStack(spacing: 6) {
                    NotificationBellView(notifications: store.notifications, onOpen: store.markAllNotificationsRead)
                    Button("スケジュール編集") { store.screen = .schedule }
                        .buttonStyle(BoardChromeButtonStyle())
                    Button("マッチ (\(store.matches.count + store.groups.count))") { store.screen = .matches }
                        .buttonStyle(BoardChromeButtonStyle())
                }
            }
            .padding(.bottom, 4)

            HStack(spacing: 6) {
                Text("職種:").font(.system(size: 11)).foregroundStyle(Theme.faint)
                Menu {
                    ForEach(Roles.all) { role in
                        Button(role.label) { store.profile?.role = role.code }
                    }
                } label: {
                    Text(Roles.label(for: store.profile?.role ?? ""))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                }
                Text("/ \(store.profile?.base ?? "") — 登録済みステイ: \(scheduleSummary)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)

            StrangerDisplayNameEditorView(profile: profileBinding)
                .padding(.bottom, 14)

            if store.isVerified {
                ReferralCodeGeneratorView(codes: myReferralCodePairs, onGenerate: store.generateReferralCode)
                    .padding(.bottom, 14)
            }

            HStack(spacing: 6) {
                modeButton(.friends, title: "知り合いから探す")
                modeButton(.strangers, title: "新しい人と探す")
            }
            .padding(.bottom, 14)

            if store.mode == .friends {
                FriendsTabView(store: store)
            } else {
                StrangersTabView(store: store)
            }
        }
    }

    private func modeButton(_ target: MatchMode, title: String) -> some View {
        Button(title) { store.mode = target }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(store.mode == target ? Theme.amber : Theme.muted)
            .background(store.mode == target ? Theme.amberBackground : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(store.mode == target ? Theme.amber : Theme.fieldBorder))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
