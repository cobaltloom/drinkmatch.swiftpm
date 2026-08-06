import SwiftUI

/// "知り合いから探す" — free, no-verification matching against friends
/// added via invite code.
struct FriendsTabView: View {
    var store: AppStore

    @State private var code = ""
    @State private var errorMessage = ""
    @State private var tabMode: OfferTabMode = .individual

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BoardCard {
                Text("招待コードで知り合いを追加").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.bottom, 6)
                HStack(spacing: 8) {
                    TextField("例: PILOT2024", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    Button("追加") { Task { await addFriend() } }
                        .buttonStyle(BoardOutlineButtonStyle())
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 11)).foregroundStyle(Theme.red).padding(.top, 6)
                }
            }

            InviteCodeGeneratorView(codes: store.myInviteCodes, onGenerate: { Task { await store.generateInviteCode() } })

            OfferTabModeSwitcher(mode: $tabMode)

            if tabMode == .group {
                GroupOrganizerView(
                    mySchedule: store.mySchedule,
                    candidates: store.friends,
                    showFullName: true,
                    overlapByCandidateID: store.overlapCache,
                    onSubmit: { day, location, members, autoAccept in
                        Task { await store.createGroupOffer(day: day, location: location, members: members, autoAccept: autoAccept) }
                    }
                )
            } else if store.friends.isEmpty {
                Text("まだ知り合いが登録されていません。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.friends) { person in
                    PersonCardView(
                        person: person,
                        overlap: store.overlapCache[person.id] ?? [],
                        offerStatus: store.status(for: person.id),
                        showFullName: true,
                        defaultAutoAccept: true,
                        onOffer: { person, overlap, autoAccept in
                            Task { await store.sendOffer(to: person, day: overlap.day, location: overlap.location, autoAccept: autoAccept) }
                        },
                        onPass: nil,
                        onReport: { person, reason, details in
                            await store.submitReport(reportedUserID: person.id, reason: reason, details: details)
                        },
                        onBlock: { person in await store.blockUser(person.id) }
                    )
                }
            }
        }
        .task {
            await store.loadFriends()
            await store.loadMyInviteCodes()
        }
    }

    private func addFriend() async {
        if let error = await store.addFriend(byInviteCode: code) {
            errorMessage = error
        } else {
            code = ""
            errorMessage = ""
        }
    }
}
