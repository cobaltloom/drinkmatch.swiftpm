import SwiftUI

/// "新しい人と探す" — gated behind identity verification and a monthly
/// subscription before the actual search UI is shown.
struct StrangersTabView: View {
    var store: DrinkMatchStore

    var body: some View {
        if (store.profile?.airline ?? "").isEmpty {
            AirlineRequiredGateView(onSubmit: { airline in await store.updateAirline(airline) })
        } else if !store.isVerified {
            EmailVerifyGateView(
                onSubmitEmail: { email in await store.verifyEmail(email) },
                onSubmitReferralCode: { code in await store.redeemReferralCodeForVerification(code) }
            )
        } else if !store.isSubscribed {
            PaywallGateView(store: store)
        } else {
            StrangersSearchView(store: store)
        }
    }
}

/// Same-company preference for stranger search — some users want to avoid
/// being matched with colleagues from their own airline, others want the
/// opposite (e.g. specifically looking to meet up with them).
private enum CompanyFilter: CaseIterable {
    case any, sameOnly, excludeSame

    var label: String {
        switch self {
        case .any: return "会社:指定なし"
        case .sameOnly: return "同じ会社のみ"
        case .excludeSame: return "同じ会社を除く"
        }
    }
}

private struct StrangersSearchView: View {
    var store: DrinkMatchStore

    @State private var filterBase = "ALL"
    @State private var filterRole = "ALL"
    @State private var companyFilter: CompanyFilter = .any
    @State private var tabMode: OfferTabMode = .individual

    /// Only candidates who actually share a free day/airport with me — a
    /// candidate with no overlap has nothing to offer on, so surfacing them
    /// here was just noise. Also applies the same-company preference: a
    /// candidate with no airline on file can't be confirmed either way, so
    /// "同じ会社のみ" excludes them (unconfirmed isn't a match) while
    /// "同じ会社を除く" keeps them (unconfirmed isn't excluded either).
    private var matchingCandidates: [Person] {
        store.strangerCandidates.filter { candidate in
            guard !(store.overlapCache[candidate.id] ?? []).isEmpty else { return false }
            switch companyFilter {
            case .any: return true
            case .sameOnly: return !candidate.airline.isEmpty && candidate.airline == store.profile?.airline
            case .excludeSame: return candidate.airline.isEmpty || candidate.airline != store.profile?.airline
            }
        }
    }

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

                companyFilterMenu

                if matchingCandidates.isEmpty {
                    Text("現在、予定が重なる新しい人はいません。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(matchingCandidates) { person in
                        PersonCardView(
                            person: person,
                            overlap: store.overlapCache[person.id] ?? [],
                            offerStatus: store.status(for: person.id),
                            showFullName: false,
                            showBase: false,
                            defaultAutoAccept: false,
                            onOffer: { person, overlap, autoAccept in
                                Task { await store.sendOffer(to: person, day: overlap.day, location: overlap.location, autoAccept: autoAccept) }
                            },
                            onPass: { person in Task { await store.pass(person) } },
                            onReport: { person, reason, details in
                                await store.submitReport(reportedUserID: person.id, reason: reason, details: details)
                            },
                            onBlock: { person in await store.blockUser(person.id) }
                        )
                    }
                }
            }
        }
        .task(id: "\(filterBase)|\(filterRole)") {
            await store.loadStrangerCandidates(baseAirport: filterBase, role: filterRole)
        }
    }

    private var companyFilterMenu: some View {
        Menu {
            ForEach(CompanyFilter.allCases, id: \.self) { option in
                Button(option.label) { companyFilter = option }
            }
        } label: {
            HStack(spacing: 4) {
                Text(companyFilter.label)
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
