import SwiftUI

/// Full-bleed navy background with a centered, width-capped content column —
/// the shared shell every top-level screen in the app sits inside.
struct BoardScreenContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }
}
