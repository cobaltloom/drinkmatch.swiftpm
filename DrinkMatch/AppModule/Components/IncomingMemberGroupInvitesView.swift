import SwiftUI

/// Pending invites from an existing group member who added this user
/// directly — see DrinkMatchStore.incomingMemberGroupInvites/
/// respondToMemberGroupInvite. Shown with full identity (not the
/// stranger-safe display name), same reasoning as IncomingFriendRequestsView:
/// the inviter must already be a friend to send one.
struct IncomingMemberGroupInvitesView: View {
    var invites: [MemberGroupInvite]
    var onRespond: (MemberGroupInvite, Bool) -> Void

    var body: some View {
        if !invites.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("グループ招待 (\(invites.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.amber)

                ForEach(invites) { invite in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.groupName).font(.system(size: 13, weight: .bold))
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Roles.label(for: invite.fromRole)).splitFlap(11).foregroundStyle(Theme.amber)
                                Text("\(invite.fromFullName)さんから").font(.system(size: 11)).foregroundStyle(Theme.faint)
                            }
                        }
                        Spacer()
                        Button("承諾") { onRespond(invite, true) }
                            .buttonStyle(BoardOutlineButtonStyle())
                        Button("拒否") { onRespond(invite, false) }
                            .buttonStyle(BoardChromeButtonStyle())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
        }
    }
}
