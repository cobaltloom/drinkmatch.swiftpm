import SwiftUI

/// Full-bleed navy background with a centered, width-capped content column —
/// the shared shell every top-level screen in the app sits inside.
struct BoardScreenContainer<Content: View>: View {
    /// When true, content shorter than the screen is centered vertically
    /// instead of sitting at the top — for screens with no form fields to
    /// scroll to (e.g. SignInView).
    var centerVertically: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .padding(16)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .frame(minHeight: centerVertically ? geometry.size.height : nil)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }
}
