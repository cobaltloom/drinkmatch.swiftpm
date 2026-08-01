import SwiftUI

/// Presented as a sheet from a person's card / match detail. Report and
/// block are independent actions (App Store Review Guideline 1.2 requires
/// both to be available for any user-to-user interaction): reporting alone
/// leaves the match/candidate in place, while blocking removes the person
/// from every list immediately (see AppStore.blockUser) and can be done
/// with or without filing a report first.
struct ReportBlockSheet: View {
    var person: Person
    var onSubmitReport: (ReportReason, String) async -> String?
    var onBlock: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = .harassment
    @State private var details = ""
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @State private var reportSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(person.displayName(showFullName: person.fullName != nil))を報告・ブロック")
                    .splitFlap(16, weight: .bold)
                    .foregroundStyle(Theme.amber)

                reportSection

                Divider().background(Theme.divider)

                blockSection

                Button("閉じる") { dismiss() }
                    .buttonStyle(BoardChromeButtonStyle())
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    @ViewBuilder
    private var reportSection: some View {
        if reportSent {
            Text("報告を送信しました。").font(.system(size: 13)).foregroundStyle(Theme.green)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("報告理由").font(.system(size: 12)).foregroundStyle(Theme.muted)
                VStack(spacing: 6) {
                    ForEach(ReportReason.allCases) { reasonRow($0) }
                }

                Text("詳細(任意)").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 4)
                TextField("状況を具体的に記入してください", text: $details, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 11)).foregroundStyle(Theme.red)
                }

                Button(isSubmitting ? "送信中…" : "報告を送信") { Task { await submitReport() } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isSubmitting))
                    .disabled(isSubmitting)
            }
        }
    }

    private func reasonRow(_ candidate: ReportReason) -> some View {
        Button { reason = candidate } label: {
            HStack {
                Image(systemName: reason == candidate ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(reason == candidate ? Theme.amber : Theme.faint)
                Text(candidate.label).font(.system(size: 13)).foregroundStyle(Theme.text)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var blockSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ブロックすると、このユーザーとはお互いに検索・誘い・グループ招待ができなくなり、既存のマッチも解除されます。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await block() }
            } label: {
                Text("ブロックする")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(Theme.red)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.red, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func submitReport() async {
        isSubmitting = true
        errorMessage = ""
        if let error = await onSubmitReport(reason, details) {
            errorMessage = error
        } else {
            reportSent = true
        }
        isSubmitting = false
    }

    private func block() async {
        await onBlock()
        dismiss()
    }
}
