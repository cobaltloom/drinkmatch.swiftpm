import SwiftUI

/// "知り合いから探す" — free, no-verification matching against friends
/// added via invite code.
///
/// No invite/accept flow here at all (individual or group) — friends are
/// assumed to already have each other's contact info (LINE, etc.), so this
/// screen is just for seeing who else is free when you are and adding new
/// friends by invite code; coordinating a meetup happens outside the app.
/// The group-offer flow (OfferTabModeSwitcher/GroupOrganizerView) exists
/// purely to submit an invite, so unlike PersonCardView's overlap listing
/// it has nothing left to show once that action is gone — StrangersTabView
/// still uses it, since strangers still need the in-app invite/accept
/// handshake.
struct FriendsTabView: View {
    var store: DrinkMatchStore

    @State private var code = ""
    @State private var errorMessage = ""

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

            if store.friends.isEmpty {
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
                        onOffer: nil,
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
