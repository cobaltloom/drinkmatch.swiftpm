import SwiftUI

/// One row in the schedule editor: a selected off-day with its stay airport,
/// the time the user is free from, and (for friends only) a per-day
/// visibility toggle.
struct StayEntryEditorView: View {
    @Binding var entry: StayEntry
    var friends: [Person]
    var onRemove: () -> Void

    @State private var showingHideOptions = false
    /// Remembers the last specific time so unchecking "一日中OK" restores it
    /// instead of leaving the picker at midnight.
    @State private var savedTime = "19:00"

    private var isAllDay: Bool { entry.from == "00:00" }

    private var timeBinding: Binding<Date> {
        Binding(get: { date(fromTimeString: entry.from) }, set: { entry.from = timeString(from: $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(dateLabel(entry.day))
                    .splitFlap(12, weight: .semibold)
                    .foregroundStyle(Theme.amber)
                    .frame(width: 44, alignment: .leading)

                if !isAllDay {
                    DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Theme.amber)
                }

                Spacer()

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

            AirportAutocompleteField(code: $entry.location, placeholder: "ステイ先を選択(例: HND, 那覇)", trackUsage: true)
                .padding(.top, 2)

            Button {
                toggleAllDay()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isAllDay ? "checkmark.square.fill" : "square")
                    Text("一日中OK")
                }
                .font(.system(size: 11))
                .foregroundStyle(isAllDay ? Theme.amber : Theme.muted)
            }
            .buttonStyle(.plain)

            if !friends.isEmpty {
                Button {
                    showingHideOptions.toggle()
                } label: {
                    Text(entry.hiddenFrom.isEmpty ? "特定の知り合いに非公開にする ▾" : "この日を\(entry.hiddenFrom.count)人に非公開中 ▾")
                        .font(.system(size: 11))
                        .foregroundStyle(entry.hiddenFrom.isEmpty ? Theme.faint : Theme.red)
                }
                .buttonStyle(.plain)

                if showingHideOptions {
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

    private func toggleAllDay() {
        if isAllDay {
            entry.from = savedTime
        } else {
            savedTime = entry.from
            entry.from = "00:00"
        }
    }

    private func toggleHidden(_ friendID: UUID) {
        if let index = entry.hiddenFrom.firstIndex(of: friendID) {
            entry.hiddenFrom.remove(at: index)
        } else {
            entry.hiddenFrom.append(friendID)
        }
    }
}
