import SwiftUI

/// One selectable row inside the group-offer organizer.
struct GroupCandidateRowView: View {
    var person: Person
    var showFullName: Bool
    var selected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Theme.amber : Theme.faint)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.role).splitFlap(12, weight: .bold).foregroundStyle(Theme.amber)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(person.airline) / \(person.base)").font(.system(size: 14, weight: .bold))
                        Text("(\(person.displayName(showFullName: showFullName)))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                    }
                    Text(person.note).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(selected ? Theme.amber : Theme.cardBorder))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.text)
        .padding(.bottom, 8)
    }
}
