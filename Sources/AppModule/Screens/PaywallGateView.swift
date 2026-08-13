import SwiftUI

/// Monthly-plan paywall shown after identity verification, before stranger
/// matching unlocks. Price/product info comes live from StoreKit; purchases
/// are verified server-side before `isSubscribed` actually flips — see
/// DrinkMatchStore.purchaseSubscription/restorePurchases and drinkmatch-backend's
/// README "Billing".
struct PaywallGateView: View {
    var store: DrinkMatchStore

    var body: some View {
        BoardCard {
            VStack(spacing: 6) {
                Text("新しい人を探す機能は月額プランです")
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

            if let product = store.subscriptionProduct {
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(product.displayPrice).splitFlap(22, weight: .bold).foregroundStyle(Theme.amber)
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

                Button(store.isPurchasing ? "処理中…" : "購入して新しい人を探す") {
                    Task { await store.purchaseSubscription() }
                }
                .buttonStyle(BoardButtonStyle(isDisabled: store.isPurchasing))
                .disabled(store.isPurchasing)
            } else {
                ProgressView().tint(Theme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)
            }

            Button("購入を復元") { Task { await store.restorePurchases() } }
                .buttonStyle(BoardChromeButtonStyle())
                .padding(.top, 8)
        }
        .task { await store.loadSubscriptionProduct() }
    }
}
