import SwiftUI

/// Expandable panel where a user issues their own invite code to hand to a
/// known acquaintance (free, unlimited — unlike the capped referral codes
/// used for identity verification).
struct InviteCodeGeneratorView: View {
    var codes: [(code: String, used: Bool)]
    var onGenerate: () -> Void

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("この招待コードを知り合いに伝えると、あなたを知り合いとして追加できます。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if codes.isEmpty {
                    Text("まだ発行したコードはありません")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                } else {
                    ForEach(codes, id: \.code) { entry in
                        HStack {
                            Text(entry.code).splitFlap(12).foregroundStyle(Theme.amber)
                            Spacer()
                            Text(entry.used ? "使用済み" : "未使用")
                                .font(.system(size: 12))
                                .foregroundStyle(entry.used ? Theme.green : Theme.muted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }

                Button("新しい招待コードを発行") { onGenerate() }
                    .buttonStyle(BoardButtonStyle())
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
        } label: {
            Text("招待コードを発行する (\(codes.count))")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .tint(Theme.muted)
    }
}
