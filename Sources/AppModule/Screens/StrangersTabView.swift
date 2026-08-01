import SwiftUI

/// "新しい人と探す" — gated behind identity verification and a monthly
/// subscription before the actual search UI is shown.
struct StrangersTabView: View {
    var store: AppStore

    var body: some View {
        if !store.isVerified {
            EmailVerifyGateView(
                onSubmitEmail: { email in await store.verifyEmail(email) },
                onSubmitReferralCode: { code in await store.redeemReferralCodeForVerification(code) }
            )
        } else if !store.isSubscribed {
            PaywallGateView(onSubscribed: { Task { await store.markSubscribed() } })
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OfferTabModeSwitcher(mode: $tabMode)

            if tabMode == .group {
                GroupOrganizerView(
                    mySchedule: store.mySchedule,
                    candidates: store.strangerCandidates,
                    showFullName: false,
                    overlapByCandidateID: store.overlapCache,
                    onSubmit: { day, location, members, autoAccept in
                        Task { await store.createGroupOffer(day: day, location: location, members: members, autoAccept: autoAccept) }
                    }
                )
            } else {
                HStack(alignment: .top, spacing: 8) {
                    AirportAutocompleteField(code: $filterBase, placeholder: "拠点で絞り込み", allowAll: true)
                    roleFilterMenu
                }

                if store.strangerCandidates.isEmpty {
                    Text("候補はすべて確認済みです。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(store.strangerCandidates) { person in
                        PersonCardView(
                            person: person,
                            overlap: store.overlapCache[person.id] ?? [],
                            offerStatus: store.status(for: person.id),
                            showFullName: false,
                            defaultAutoAccept: false,
                            onOffer: { person, overlap, autoAccept in
                                Task { await store.sendOffer(to: person, day: overlap.day, location: overlap.location, autoAccept: autoAccept) }
                            },
                            onPass: { person in Task { await store.pass(person) } }
                        )
                    }
                }
            }
        }
        .task(id: "\(filterBase)|\(filterRole)") {
            await store.loadStrangerCandidates(baseAirport: filterBase, role: filterRole)
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
