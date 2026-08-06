import SwiftUI

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
