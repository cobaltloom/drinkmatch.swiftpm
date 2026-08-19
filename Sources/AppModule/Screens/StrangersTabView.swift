import SwiftUI

/// "新しい人を探す" — gated behind identity verification and a monthly
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

/// Age-difference preference for stranger search, compared against the
/// signed-in user's own `birthYear` (self-reported, year-only — see
/// UserProfile.birthYear). Like the same-company filter, a candidate that
/// can't be confirmed either way (their birth year isn't set, or mine
/// isn't) is excluded from anything but `.any` rather than assumed to pass.
private enum AgeDiffFilter: CaseIterable {
    case within5, within7, within10, any

    var label: String {
        switch self {
        case .within5: return "年齢差5歳以内"
        case .within7: return "年齢差7歳以内"
        case .within10: return "年齢差10歳以内"
        case .any: return "年齢:気にしない"
        }
    }

    var maxDiff: Int? {
        switch self {
        case .within5: return 5
        case .within7: return 7
        case .within10: return 10
        case .any: return nil
        }
    }
}

private struct StrangersSearchView: View {
    var store: DrinkMatchStore

    @State private var filterBase = "ALL"
    @State private var filterRole = "ALL"
    @State private var companyFilter: CompanyFilter = .any
    @State private var ageDiffFilter: AgeDiffFilter = .any
    @State private var tabMode: OfferTabMode = .individual

    /// Only candidates who actually share a free day/airport with me — a
    /// candidate with no overlap has nothing to offer on, so surfacing them
    /// here was just noise. Also applies the same-company preference: a
    /// candidate with no airline on file can't be confirmed either way, so
    /// "同じ会社のみ" excludes them (unconfirmed isn't a match) while
    /// "同じ会社を除く" keeps them (unconfirmed isn't excluded either). Same
    /// treatment for the age-difference filter: an unconfirmed birth year
    /// (mine or theirs) excludes the candidate rather than passing them.
    private var matchingCandidates: [Person] {
        store.strangerCandidates.filter { candidate in
            guard !(store.overlapCache[candidate.id] ?? []).isEmpty else { return false }
            guard passesAgeFilter(candidate) else { return false }
            switch companyFilter {
            case .any: return true
            case .sameOnly: return !candidate.airline.isEmpty && candidate.airline == store.profile?.airline
            case .excludeSame: return candidate.airline.isEmpty || candidate.airline != store.profile?.airline
            }
        }
    }

    private func passesAgeFilter(_ candidate: Person) -> Bool {
        guard let maxDiff = ageDiffFilter.maxDiff else { return true }
        guard let myBirthYear = store.profile?.birthYear, let candidateBirthYear = candidate.birthYear else { return false }
        return abs(myBirthYear - candidateBirthYear) <= maxDiff
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

                HStack(spacing: 8) {
                    companyFilterMenu
                    ageFilterMenu
                }

                if ageDiffFilter != .any && store.profile?.birthYear == nil {
                    Text("年齢差フィルターを使うには、プロフィールで生まれ年を設定してください。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                            offerID: store.offerID(for: person.id),
                            showFullName: false,
                            showBase: false,
                            defaultAutoAccept: false,
                            onOffer: { person, overlap, autoAccept in
                                Task { await store.sendOffer(to: person, day: overlap.day, location: overlap.location, autoAccept: autoAccept) }
                            },
                            onPass: { person in Task { await store.pass(person) } },
                            onCancelOffer: { offerID in Task { await store.cancelOffer(offerID: offerID) } },
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

    private var ageFilterMenu: some View {
        Menu {
            ForEach(AgeDiffFilter.allCases, id: \.self) { option in
                Button(option.label) { ageDiffFilter = option }
            }
        } label: {
            HStack(spacing: 4) {
                Text(ageDiffFilter.label)
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
