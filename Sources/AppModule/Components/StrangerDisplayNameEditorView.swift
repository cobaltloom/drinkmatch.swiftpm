import SwiftUI

/// Expandable control on the main screen letting the user switch between
/// showing initials or a chosen nickname to strangers.
struct StrangerDisplayNameEditorView: View {
    @Binding var profile: UserProfile

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("表示名", selection: $profile.displayMode) {
                    Text("イニシャル").tag(DisplayMode.initials)
                    Text("ニックネーム").tag(DisplayMode.nickname)
                }
                .pickerStyle(.segmented)

                if profile.displayMode == .nickname {
                    TextField("例: そらまめ", text: $profile.nickname)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Theme.field)
                        .foregroundStyle(Theme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.cardBorder))
        } label: {
            HStack(spacing: 0) {
                Text("新しい人を探すでの表示名: ")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                Text(profile.strangerDisplayName.isEmpty ? "(未入力)" : profile.strangerDisplayName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.amber)
            }
        }
        .tint(Theme.muted)
    }
}
