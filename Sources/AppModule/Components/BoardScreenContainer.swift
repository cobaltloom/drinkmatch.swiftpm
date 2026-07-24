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

/// Rounded card used to group related fields, matching the board's
/// dark-panel-on-navy look.
struct BoardCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
    }
}
