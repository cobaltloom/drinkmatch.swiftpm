import SwiftUI

/// Monthly-plan paywall shown after identity verification, before stranger
/// matching unlocks. Price is a placeholder (handoff doc §9).
struct PaywallGateView: View {
    var onSubscribed: () -> Void

    var body: some View {
        BoardCard {
            VStack(spacing: 6) {
                Text("新しい人と探す機能は月額プランです")
                    .splitFlap(14, weight: .bold)
                    .foregroundStyle(Theme.amber)
                    .multilineTextAlignment(.center)
                Text("知り合いとのマッチングは無料でご利用いただけます。見ず知らずの航空従事者と会う機能は、本人確認の運用コストがかかるため月額プランとしています。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("¥980").splitFlap(22, weight: .bold).foregroundStyle(Theme.amber)
                    Text(" / 月").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Text("いつでも解約可能").font(.system(size: 11)).foregroundStyle(Theme.faint)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
            .padding(.bottom, 14)

            Button("(デモ)購入して新しい人と探す") { onSubscribed() }
                .buttonStyle(BoardButtonStyle())
        }
    }
}
