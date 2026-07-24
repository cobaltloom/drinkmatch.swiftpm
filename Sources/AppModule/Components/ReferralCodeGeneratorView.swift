import SwiftUI

/// Expandable panel where an already-verified user can issue up to
/// `maxReferralCodesPerUser` identity-verification referral codes for
/// juniors without a company email.
struct ReferralCodeGeneratorView: View {
    var codes: [(code: String, used: Bool)]
    var onGenerate: () -> Void

    @State private var expanded = false

    private var atCap: Bool { codes.count >= maxReferralCodesPerUser }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("会社メールを持たない後輩・知人が新規マッチング機能を使えるように、紹介コードを発行できます(1人あたり\(maxReferralCodesPerUser)件まで)。")
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

                Button(atCap ? "発行上限に達しました" : "新しい紹介コードを発行") {
                    onGenerate()
                }
                .buttonStyle(BoardButtonStyle(isDisabled: atCap))
                .disabled(atCap)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
        } label: {
            Text("後輩に紹介コードを発行する (\(codes.count)/\(maxReferralCodesPerUser))")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .tint(Theme.muted)
    }
}
