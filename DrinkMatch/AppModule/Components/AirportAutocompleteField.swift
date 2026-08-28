import SwiftUI

/// A search-as-you-type airport picker. Binds to an airport code (or the
/// sentinel `"ALL"` when `allowAll` is set and nothing specific is picked).
struct AirportAutocompleteField: View {
    @Binding var code: String
    var placeholder: String = "空港コードまたは名前で検索(例: HND, 那覇)"
    var allowAll: Bool = false
    /// When true, picking a suggestion records it in `AirportUsageTracker`
    /// and the suggestion list is sorted most-picked-first — worth enabling
    /// where the same person repeatedly picks from a real, personal set of
    /// airports (e.g. stay locations), not for a one-off pick like a home
    /// base or an unrelated search filter.
    var trackUsage: Bool = false

    @State private var query: String = ""
    @FocusState private var focused: Bool

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var suggestions: [Airport] {
        let matches = trimmedQuery.isEmpty
            ? StayAirports.all
            : StayAirports.all.filter {
                $0.code.localizedCaseInsensitiveContains(trimmedQuery) || $0.name.contains(trimmedQuery)
            }
        guard trackUsage else { return matches }
        // `sorted(by:)` isn't guaranteed stable, so ties (most airports,
        // which have no recorded uses) break on original list order via the
        // enumerated offset rather than however the sort happens to shuffle them.
        return matches.enumerated()
            .sorted { lhs, rhs in
                let lhsCount = AirportUsageTracker.count(for: lhs.element.code)
                let rhsCount = AirportUsageTracker.count(for: rhs.element.code)
                return lhsCount != rhsCount ? lhsCount > rhsCount : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private var showAllOption: Bool {
        allowAll && ("全拠点".contains(trimmedQuery) || trimmedQuery.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $query)
                .font(.system(size: 14))
                .padding(10)
                .background(Theme.field)
                .foregroundStyle(Theme.text)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                .focused($focused)

            if focused && (showAllOption || !suggestions.isEmpty) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if showAllOption {
                            suggestionRow(code: "ALL", label: "全拠点", subtitle: nil)
                        }
                        ForEach(suggestions) { airport in
                            suggestionRow(code: airport.code, label: airportLabel(airport.code), subtitle: airport.code)
                        }
                    }
                }
                .frame(maxHeight: 180)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
            }
        }
        .onAppear { query = label(for: code) }
    }

    private func suggestionRow(code airportCode: String, label: String, subtitle: String?) -> some View {
        Button {
            code = airportCode
            query = label
            focused = false
            if trackUsage { AirportUsageTracker.recordUse(airportCode) }
        } label: {
            HStack {
                if let subtitle {
                    Text(subtitle).splitFlap(12).foregroundStyle(Theme.amber)
                }
                Text(subtitle == nil ? label : String(label.dropFirst(subtitle!.count)))
                    .font(.system(size: 13))
                    .foregroundStyle(subtitle == nil ? Theme.muted : Theme.text)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .overlay(Divider().background(Theme.divider), alignment: .bottom)
    }

    private func label(for code: String) -> String {
        if allowAll && (code == "ALL" || code.isEmpty) { return "全拠点" }
        return code.isEmpty ? "" : airportLabel(code)
    }
}
