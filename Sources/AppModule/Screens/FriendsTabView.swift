import SwiftUI

/// "知り合いから探す" — free, no-verification matching against friends
/// added via invite code.
struct FriendsTabView: View {
    var store: AppStore

    @State private var code = ""
    @State private var errorMessage = ""
    @State private var tabMode: OfferTabMode = .individual

    private var sortedFriends: [Person] {
        store.friends.sorted { overlapCount(for: $0) > overlapCount(for: $1) }
    }

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
                    Button("追加") { addFriend() }
                        .buttonStyle(BoardOutlineButtonStyle())
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 11)).foregroundStyle(Theme.red).padding(.top, 6)
                }
            }

            OfferTabModeSwitcher(mode: $tabMode)

            if tabMode == .group {
                GroupOrganizerView(
                    mySchedule: store.mySchedule,
                    candidates: store.friends,
                    showFullName: true,
                    viewerAware: true,
                    onSubmit: store.createGroupOffer
                )
            } else if sortedFriends.isEmpty {
                Text("まだ知り合いが登録されていません。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(sortedFriends) { person in
                    PersonCardView(
                        person: person,
                        mySchedule: store.mySchedule,
                        offerStatus: store.status(for: person.id),
                        showFullName: true,
                        defaultAutoAccept: true,
                        viewerFriendID: person.id,
                        onOffer: { store.sendOffer(to: $0, autoAccept: $1) },
                        onPass: { store.pass($0) }
                    )
                }
            }
        }
    }

    private func overlapCount(for person: Person) -> Int {
        matchStays(mine: store.mySchedule, theirs: person.stays, viewerPersonID: person.id).count
    }

    private func addFriend() {
        if let error = store.addFriend(byInviteCode: code) {
            errorMessage = error
        } else {
            code = ""
            errorMessage = ""
        }
    }
}
