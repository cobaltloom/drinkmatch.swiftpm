import SwiftUI

/// Pending requests from people who entered this user's invite code — see
/// DrinkMatchStore.incomingFriendRequests/respondToFriendRequest. Shown
/// with full identity (not the stranger-safe display name) since invite
/// codes are for people who already know each other in person.
struct IncomingFriendRequestsView: View {
    var requests: [FriendRequest]
    var onRespond: (FriendRequest, Bool) -> Void

    var body: some View {
        if !requests.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("知り合いリクエスト (\(requests.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.amber)

                ForEach(requests) { request in
                    HStack {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Roles.label(for: request.role)).splitFlap(12).foregroundStyle(Theme.amber)
                            Text(request.fullName).font(.system(size: 13, weight: .bold))
                            if !request.airline.isEmpty {
                                Text("(\(airlineLabel(request.airline)))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.faint)
                            }
                        }
                        Spacer()
                        Button("承諾") { onRespond(request, true) }
                            .buttonStyle(BoardOutlineButtonStyle())
                        Button("拒否") { onRespond(request, false) }
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
