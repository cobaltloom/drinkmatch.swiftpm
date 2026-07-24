import SwiftUI

/// One row in the schedule editor: a selected off-day with its stay airport,
/// the time the user is free from, and (for friends only) a per-day
/// visibility toggle.
struct StayEntryEditorView: View {
    @Binding var entry: StayEntry
    var friends: [Person]
    var onRemove: () -> Void

    @State private var showHideOptions = false

    private var timeBinding: Binding<Date> {
        Binding(get: { date(fromTimeString: entry.from) }, set: { entry.from = timeString(from: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(fmtDate(entry.day))
                    .splitFlap(12, weight: .semibold)
                    .foregroundStyle(Theme.amber)
                    .frame(width: 44, alignment: .leading)

                Menu {
                    ForEach(StayAirports.all) { airport in
                        Button(airportLabel(airport.code)) { entry.location = airport.code }
                    }
                } label: {
                    HStack {
                        Text(entry.location.isEmpty ? "ステイ先を選択" : airportLabel(entry.location))
                            .font(.system(size: 12))
                            .foregroundStyle(entry.location.isEmpty ? Theme.faint : Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Theme.field)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(Theme.amber)

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .frame(width: 26, height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                }
            }

            if !friends.isEmpty {
                Button {
                    showHideOptions.toggle()
                } label: {
                    Text(entry.hiddenFrom.isEmpty ? "特定の知り合いに非公開にする ▾" : "この日を\(entry.hiddenFrom.count)人に非公開中 ▾")
                        .font(.system(size: 11))
                        .foregroundStyle(entry.hiddenFrom.isEmpty ? Theme.faint : Theme.red)
                }
                .buttonStyle(.plain)

                if showHideOptions {
                    FlowLayout(spacing: 6) {
                        ForEach(friends) { friend in
                            Button {
                                toggleHidden(friend.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: entry.hiddenFrom.contains(friend.id) ? "checkmark.square.fill" : "square")
                                    Text(friend.fullName ?? friend.name)
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Theme.field)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(.bottom, 10)
        .overlay(Divider().background(Theme.divider), alignment: .bottom)
    }

    private func toggleHidden(_ friendID: Int) {
        if let index = entry.hiddenFrom.firstIndex(of: friendID) {
            entry.hiddenFrom.remove(at: index)
        } else {
            entry.hiddenFrom.append(friendID)
        }
    }
}
