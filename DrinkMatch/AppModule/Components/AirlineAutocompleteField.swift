import SwiftUI

/// A search-as-you-type airline picker. Binds to a 3-letter airline code.
struct AirlineAutocompleteField: View {
    @Binding var code: String
    var placeholder: String = "会社名またはコードで検索(例: ANA, 日本航空)"

    @State private var query: String = ""
    @FocusState private var focused: Bool

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var suggestions: [Airline] {
        trimmedQuery.isEmpty
            ? Airlines.all
            : Airlines.all.filter {
                $0.code.localizedCaseInsensitiveContains(trimmedQuery) || $0.name.contains(trimmedQuery)
            }
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

            if focused && !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions) { airline in
                            suggestionRow(airline)
                        }
                    }
                }
                .frame(maxHeight: 180)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
            }
        }
        .onAppear { query = code.isEmpty ? "" : airlineLabel(code) }
    }

    private func suggestionRow(_ airline: Airline) -> some View {
        Button {
            code = airline.code
            query = airlineLabel(airline.code)
            focused = false
        } label: {
            HStack {
                Text(airline.code).splitFlap(12).foregroundStyle(Theme.amber)
                Text(airline.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .overlay(Divider().background(Theme.divider), alignment: .bottom)
    }
}
