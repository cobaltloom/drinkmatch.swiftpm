import SwiftUI

/// Shared "proposal sent" confirmation card used for both individual
/// (MatchesView) and group (GroupDetailView) meetups.
struct SentProposalSummary: View {
    var proposal: Proposal
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("集合案を送信しました").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.green)
            Text("日付: \(dateLabel(proposal.day))").font(.system(size: 13))
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
