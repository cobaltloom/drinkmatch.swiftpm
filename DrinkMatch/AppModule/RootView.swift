import SwiftUI

/// Top-level screen switcher: signed out → sign in, signed in with no
/// profile yet → onboarding, otherwise the prototype's original
/// profile → schedule → main → matches flow.
struct RootView: View {
    @State private var store = DrinkMatchStore()

    var body: some View {
        Group {
            if !SupabaseConfig.isConfigured {
                SetupNoticeView()
            } else if store.isBootstrapping {
                ProgressView().tint(Theme.amber)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background.ignoresSafeArea())
            } else if store.authUserID == nil {
                SignInView(store: store)
            } else {
                switch store.screen {
                case .profile:
                    ProfileSetupView(onDone: { profile, ageConfirmed in
                        Task { await store.completeProfile(profile, ageConfirmed: ageConfirmed) }
                    })
                case .schedule:
                    ScheduleSetupView(
                        friends: store.friends,
                        initialEntries: store.mySchedule,
                        initialYear: store.scheduleYear,
                        initialMonth: store.scheduleMonth,
                        onDone: { entries, year, month in Task { await store.completeSchedule(entries, year: year, month: month) } },
                        onMonthChange: { year, month in
                            guard let userID = store.authUserID else { return [] }
                            return await store.loadSchedule(userID: userID, year: year, month: month)
                        },
                        onCancel: { store.screen = .main }
                    )
                case .main:
                    MainView(store: store)
                case .matches:
                    MatchesView(store: store)
                }
            }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .top, spacing: 0) { TestEnvironmentBanner() }
        .task { await store.bootstrap() }
        .task { await store.observeTransactionUpdates() }
        .alert(
            "エラー",
            isPresented: Binding(get: { store.lastErrorMessage != nil }, set: { if !$0 { store.lastErrorMessage = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(store.lastErrorMessage ?? "") }
        )
    }
}

/// Persistent, impossible-to-miss reminder that this build talks to the
/// test Supabase project, not production — shown above every screen
/// (including SetupNoticeView/SignInView) regardless of app state. Renders
/// nothing at all when SupabaseConfig.environment is .production, so it's
/// zero-height and invisible on a real production build.
private struct TestEnvironmentBanner: View {
    var body: some View {
        if SupabaseConfig.environment == .test {
            Text("⚠️ TEST ENVIRONMENT — 本番データではありません")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.red)
        }
    }
}

/// Shown instead of the app when SupabaseConfig still has placeholder
/// values — avoids every screen silently failing its network calls with a
/// confusing error before setup is done.
private struct SetupNoticeView: View {
    var body: some View {
        BoardScreenContainer {
            VStack(spacing: 12) {
                Text("セットアップが必要です").splitFlap(18, weight: .bold).foregroundStyle(Theme.amber)
                Text("Sources/AppModule/Networking/SupabaseConfig.swift に、Supabaseプロジェクトの URL と anon/publishable key を設定してください。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 100)
        }
    }
}
