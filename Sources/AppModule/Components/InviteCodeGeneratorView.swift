import SwiftUI

/// Expandable panel showing this user's fixed invite code — unlike the old
/// many-single-use-codes design, there's only ever one, so this is a
/// display, not a generator (entering it now sends a friend request the
/// owner must accept, rather than instantly friending — see
/// DrinkMatchStore.sendFriendRequest/respondToFriendRequest).
struct InviteCodeGeneratorView: View {
    var code: String?

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("この招待コードを知り合いに伝えると、あなたに知り合いリクエストを送れます。承諾すると知り合いに追加されます。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let code {
                    Text(code)
                        .splitFlap(16, weight: .bold)
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    ProgressView().tint(Theme.amber)
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
        } label: {
            Text("自分の招待コード")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .tint(Theme.muted)
    }
}
