import SwiftUI

/// "新しい人と探す" — gated behind identity verification and a monthly
/// subscription before the actual search UI is shown.
struct StrangersTabView: View {
    var store: AppStore

    var body: some View {
        if !store.isVerified {
            EmailVerifyGateView(
                referralCodes: store.referralCodes,
                onUseReferralCode: store.useReferralCode,
                onVerified: store.markVerified
            )
        } else if !store.isSubscribed {
            PaywallGateView(onSubscribed: store.markSubscribed)
        } else {
            StrangersSearchView(store: store)
        }
    }
}

private struct StrangersSearchView: View {
    var store: AppStore

    @State private var filterBase = "ALL"
    @State private var filterRole = "ALL"
    @State private var tabMode: OfferTabMode = .individual

    private var candidatePool: [Person] {
        SampleStrangers.all.filter { !store.passed.contains($0.id) }
    }

    private var visible: [Person] {
        candidatePool
            .filter { filterBase == "ALL" || $0.base == filterBase }
            .filter { filterRole == "ALL" || $0.role == filterRole }
            .sorted {
                matchStays(mine: store.mySchedule, theirs: $0.stays).count
                    > matchStays(mine: store.mySchedule, theirs: $1.stays).count
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OfferTabModeSwitcher(mode: $tabMode)

            if tabMode == .group {
                GroupOrganizerView(
                    mySchedule: store.mySchedule,
                    candidates: candidatePool,
                    showFullName: false,
                    viewerAware: false,
                    onSubmit: store.createGroupOffer
                )
            } else {
                HStack(alignment: .top, spacing: 8) {
                    AirportAutocompleteField(code: $filterBase, placeholder: "拠点で絞り込み", allowAll: true)
                    roleFilterMenu
                }

                if visible.isEmpty {
                    Text("候補はすべて確認済みです。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(visible) { person in
                        PersonCardView(
                            person: person,
                            mySchedule: store.mySchedule,
                            offerStatus: store.status(for: person.id),
                            showFullName: false,
                            defaultAutoAccept: false,
                            onOffer: { store.sendOffer(to: $0, autoAccept: $1) },
                            onPass: { store.pass($0) }
                        )
                    }
                }
            }
        }
    }

    private var roleFilterMenu: some View {
        Menu {
            Button("全職種") { filterRole = "ALL" }
            ForEach(Roles.all) { role in
                Button(role.label) { filterRole = role.code }
            }
        } label: {
            HStack(spacing: 4) {
                Text(filterRole == "ALL" ? "全職種" : Roles.label(for: filterRole))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
        }
    }
}
