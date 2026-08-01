import SwiftUI

/// Detail pane for a group offer: member accept status, and — once at
/// least one member has accepted — a form to send the meetup proposal.
struct GroupDetailView: View {
    var group: DrinkGroup
    /// Needed to tell "my own membership row" (which I can accept) apart
    /// from everyone else's (read-only — accepting is `auth.uid()`-scoped
    /// server-side, so I can't act on another member's behalf).
    var myUserID: UUID?
    var onAcceptOwnMembership: () -> Void
    @Binding var composeTime: Date
    @Binding var composePlace: String
    var onSendProposal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(fmtDate(group.day)) — \(airportLabel(group.location)) のグループ")
                .font(.system(size: 14, weight: .bold))
            Text("\(group.acceptedCount) / \(group.members.count) 人が承諾済み")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            VStack(spacing: 6) {
                ForEach(group.members) { member in
                    HStack {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(member.person.role).splitFlap(12).foregroundStyle(Theme.amber)
                            Text("  \(member.person.fullName ?? member.person.name)").font(.system(size: 12))
                        }
                        Spacer()
                        if member.status == .accepted {
                            Text("承諾済み").font(.system(size: 11)).foregroundStyle(Theme.green)
                        } else if member.id == myUserID {
                            Button("参加する") { onAcceptOwnMembership() }
                                .buttonStyle(BoardOutlineButtonStyle())
                        } else {
                            Text("承諾待ち").font(.system(size: 11)).foregroundStyle(Theme.amberDim)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            if group.acceptedCount == 0 {
                Text("まだ誰も承諾していないため、集合案は送れません。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.field)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let sent = group.sentProposal {
                SentProposalSummary(proposal: sent, footnote: "承諾済みの\(group.acceptedCount)人に送信されました。")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("承諾済みメンバーに集合案を送ります")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                    DatePicker("", selection: $composeTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Theme.amber)
                    TextField("お店(例: 国際通り 居酒屋)", text: $composePlace)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    Button("送信する") { onSendProposal() }
                        .buttonStyle(BoardButtonStyle())
                }
                .padding(12)
                .background(Theme.field)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.fieldBorder))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

/// Shared "proposal sent" confirmation card used for both individual and
/// group meetups.
struct SentProposalSummary: View {
    var proposal: Proposal
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("集合案を送信しました").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.green)
            Text("日付: \(fmtDate(proposal.day))").font(.system(size: 13))
            Text("ステイ先: \(airportLabel(proposal.location))").font(.system(size: 13))
            Text("時間: \(proposal.time)").font(.system(size: 13))
            Text("場所: \(proposal.place.isEmpty ? "未定" : proposal.place)").font(.system(size: 13))
            if let footnote {
                Text(footnote).font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.greenBackground)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.greenBorder))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
