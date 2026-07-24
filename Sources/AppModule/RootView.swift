import SwiftUI

/// Top-level screen switcher, mirroring the prototype's single-`screen`
/// state machine: profile setup → schedule setup → main board → matches.
struct RootView: View {
    @State private var store = AppStore()

    var body: some View {
        Group {
            switch store.screen {
            case .profile:
                ProfileSetupView(onDone: store.completeProfile)
            case .schedule:
                ScheduleSetupView(friends: store.friends, initialEntries: store.mySchedule, onDone: store.completeSchedule)
            case .main:
                MainView(store: store)
            case .matches:
                MatchesView(store: store)
            }
        }
        .preferredColorScheme(.dark)
    }
}
