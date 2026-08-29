import SwiftUI

/// The home screen: profile summary, mode switcher (friends vs. strangers),
/// and the active tab's candidate list.
struct MainView: View {
    @Bindable var store: DrinkMatchStore

    @State private var showingProfileInfo = false
    @State private var showingBlockedUsers = false
    @State private var showingDeleteAccount = false
    @State private var contactMode: ContactMode = .oneOnOne

    private var profileBinding: Binding<UserProfile> {
        Binding(
            get: { store.profile ?? UserProfile(role: Roles.all[0].code, base: StayAirports.all[0].code, fullName: "", displayMode: .initials, nickname: "") },
            set: { newValue in
                let old = store.profile
                store.profile = newValue
                if old?.displayMode != newValue.displayMode || old?.nickname != newValue.nickname {
                    Task { await store.updateDisplayPreference(displayMode: newValue.displayMode, nickname: newValue.nickname) }
                }
            }
        )
    }

    private var scheduleSummary: String {
        let upcoming = store.mySchedule.filter {
            !BoardCalendar.isPastDay(year: BoardCalendar.year, month: BoardCalendar.month, day: $0.day)
        }
        return upcoming.isEmpty
            ? "未設定"
            : upcoming.map { "\(dateLabel($0.day))\(airportLabel($0.location))" }.joined(separator: ", ")
    }

    var body: some View {
        BoardScreenContainer {
            HStack(alignment: .firstTextBaseline) {
                Text("CrewBoard").splitFlap(20, weight: .bold).foregroundStyle(Theme.amber)
                Spacer()
                HStack(spacing: 6) {
                    NotificationBellView(notifications: store.notifications, onOpen: { Task { await store.markAllNotificationsRead() } })
                    Button {
                        store.screen = .schedule
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("スケジュール")
                        }
                    }
                    .buttonStyle(BoardChromeButtonStyle())
                    if strangerMatchingFeatureEnabled {
                        Button("マッチ (\(store.matches.count + store.groups.count))") { store.screen = .matches }
                            .buttonStyle(BoardChromeButtonStyle())
                    }
                    Menu {
                        Button("プロフィール") { showingProfileInfo = true }
                        Button("ブロック中のユーザー") { showingBlockedUsers = true }
                        Button("サインアウト", role: .destructive) { Task { await store.signOut() } }
                        Button("アカウントを削除", role: .destructive) { showingDeleteAccount = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .frame(width: 30, height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    }
                }
            }
            .padding(.bottom, 4)

            HStack(spacing: 6) {
                // Editing role/airline/base now lives in ProfileInfoView
                // (rate-limited server-side — see updateIdentity) rather
                // than an instant switch here.
                Text("職種: \(Roles.label(for: store.profile?.role ?? "")) / \(store.profile?.base ?? "") — 登録済みステイ: \(scheduleSummary)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)

            HStack(spacing: 6) {
                contactModeButton(.oneOnOne, title: "1対1")
                contactModeButton(.groups, title: "グループ")
            }
            .padding(.bottom, 14)

            if contactMode == .groups {
                GroupsTabView(store: store)
            } else {
                if strangerMatchingFeatureEnabled {
                    StrangerDisplayNameEditorView(profile: profileBinding)
                        .padding(.bottom, 14)
                }

                if strangerMatchingFeatureEnabled && store.isVerified {
                    ReferralCodeGeneratorView(codes: store.myReferralCodes, onGenerate: { Task { await store.generateReferralCode() } })
                        .padding(.bottom, 14)
                }

                if strangerMatchingFeatureEnabled {
                    HStack(spacing: 6) {
                        modeButton(.friends, title: "知り合いから探す")
                        modeButton(.strangers, title: "新しい人を探す")
                    }
                    .padding(.bottom, 14)
                }

                if strangerMatchingFeatureEnabled && store.mode == .strangers {
                    StrangersTabView(store: store)
                } else {
                    FriendsTabView(store: store)
                }
            }
        }
        .task {
            await store.loadNotifications()
            if strangerMatchingFeatureEnabled && store.isVerified { await store.loadMyReferralCodes() }
        }
        .sheet(isPresented: $showingProfileInfo) {
            ProfileInfoView(store: store)
        }
        .sheet(isPresented: $showingBlockedUsers) {
            BlockedUsersView(store: store)
        }
        .sheet(isPresented: $showingDeleteAccount) {
            DeleteAccountView(store: store)
        }
    }

    private func contactModeButton(_ target: ContactMode, title: String) -> some View {
        Button(title) { contactMode = target }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(contactMode == target ? Theme.amber : Theme.muted)
            .background(contactMode == target ? Theme.amberBackground : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(contactMode == target ? Theme.amber : Theme.fieldBorder))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
