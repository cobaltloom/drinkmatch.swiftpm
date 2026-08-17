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

                if let count = store.strangerCandidateCount {
                    Text(count > 0
                        ? "現在、予定が重なる新しい人が\(count)人います。"
                        : "現在、条件に合う新しい人はまだ見つかっていません。予定を登録すると見つかりやすくなります。")
                        .font(.system(size: 12))
                        .foregroundStyle(count > 0 ? Theme.amber : Theme.faint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
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

                // App Store Review Guideline 3.1.2: subscription title,
                // length, and price, all near the purchase button.
                Text("「新しい人を探す」月額プラン: 1ヶ月ごとに\(product.displayPrice)で自動更新されます。解約しない限り自動的に更新され、解約は次回更新日の24時間前までにApp Storeの設定から行ってください。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            } else {
                ProgressView().tint(Theme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)
            }

            Button("購入を復元") { Task { await store.restorePurchases() } }
                .buttonStyle(BoardChromeButtonStyle())
                .padding(.top, 8)

            HStack(spacing: 16) {
                Link("利用規約", destination: termsOfUseURL)
                Link("プライバシーポリシー", destination: privacyPolicyURL)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)
            .padding(.top, 10)
        }
        .task { await store.loadSubscriptionProduct() }
        .task { await store.loadStrangerCandidateCount() }
    }
}
