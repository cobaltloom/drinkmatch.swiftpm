import SwiftUI
import StoreKit

/// A one-time, no-strings-attached "buy the developer a drink" tip — unlike
/// PaywallGateView's subscription, this unlocks nothing. Purely goodwill,
/// so there's no server verification (see DrinkMatchStore.purchaseTip) and
/// no restore-purchases button — consumables aren't restorable.
struct SupportDeveloperView: View {
    var store: DrinkMatchStore

    var body: some View {
        BoardScreenContainer {
            Text("開発者を応援する")
                .splitFlap(18, weight: .bold)
                .foregroundStyle(Theme.amber)
                .padding(.bottom, 8)

            Text("CrewBoardは個人で開発・運営しています。よろしければ、開発者に一杯おごってください。購入しても新しい機能がアンロックされるわけではなく、純粋な応援です。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            if let thankYou = store.tipThankYouMessage {
                Text(thankYou)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }

            if store.tipProducts.isEmpty {
                ProgressView().tint(Theme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.tipProducts) { product in
                        Button {
                            Task { await store.purchaseTip(product) }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                            }
                        }
                        .buttonStyle(BoardButtonStyle(isDisabled: store.isTipping))
                        .disabled(store.isTipping)
                    }
                }
            }

            if let storeMessage = store.lastErrorMessage {
                Text(storeMessage).font(.system(size: 12)).foregroundStyle(Theme.red).padding(.top, 12)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("楽天市場で買い物する").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                Text("いつも通りお買い物いただくだけで、購入価格の上乗せなしに開発者へ少額の紹介料が入ります。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
                Link("楽天市場を開く", destination: rakutenAffiliateURL)
                    .buttonStyle(BoardOutlineButtonStyle())
            }
            .padding(.top, 20)
        }
        .task { await store.loadTipProducts() }
    }
}
