import SwiftUI

/// Shared "1対1で誘う / グループを作る" switcher used by both the friends
/// and strangers tabs.
struct OfferTabModeSwitcher: View {
    @Binding var mode: OfferTabMode

    var body: some View {
        HStack(spacing: 6) {
            button(.individual, title: "1対1で誘う")
            button(.group, title: "グループを作る")
        }
    }

    private func button(_ target: OfferTabMode, title: String) -> some View {
        Button(title) { mode = target }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(mode == target ? Theme.amber : Theme.muted)
            .background(mode == target ? Theme.amberBackground : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(mode == target ? Theme.amber : Theme.fieldBorder)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
