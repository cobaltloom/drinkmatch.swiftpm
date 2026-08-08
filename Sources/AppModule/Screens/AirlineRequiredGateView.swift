import SwiftUI

/// Onboarding leaves "会社" optional to keep the initial signup bar low,
/// but stranger matching (StrangersTabView) needs it — this gate collects
/// it the first time someone actually opens "新しい人を探す".
struct AirlineRequiredGateView: View {
    var onSubmit: (String) async -> Void

    @State private var airline = ""
    @State private var isSubmitting = false

    var body: some View {
        BoardCard {
            VStack(spacing: 6) {
                Text("会社の登録が必要です")
                    .splitFlap(14, weight: .bold)
                    .foregroundStyle(Theme.amber)
                Text("新しい人を探す機能を使うには、所属する会社を登録してください。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            AirlineAutocompleteField(code: $airline)

            Button("登録して新しい人と探す") { Task { await submit() } }
                .buttonStyle(BoardButtonStyle(isDisabled: airline.isEmpty || isSubmitting))
                .disabled(airline.isEmpty || isSubmitting)
                .padding(.top, 12)
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        await onSubmit(airline)
    }
}
