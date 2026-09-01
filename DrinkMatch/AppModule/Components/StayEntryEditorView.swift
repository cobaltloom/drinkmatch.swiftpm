import SwiftUI

/// One row in the schedule editor: a selected off-day with its stay airport,
/// the time the user is free from, a per-day opt-in for stranger visibility
/// (off by default — see StayEntry.visibleToStrangers), and a per-day
/// hide-from-specific-friends toggle.
struct StayEntryEditorView: View {
    @Binding var entry: StayEntry
    var friends: [Person]
    /// The schedule editor's currently-navigated month — needed here only
    /// to label the row correctly, since `entry.day` is a bare day-of-month
    /// int with no month of its own (see ScheduleSetupView).
    var month: Int
    /// The user's base airport, auto-filled into `entry.location` when
    /// "一日中OK" is turned on and the stay location hasn't been set yet —
    /// an all-day-free entry is typically a day at home base.
    var baseAirport: String
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
                Text(dateLabel(month: month, day: entry.day))
                    .splitFlap(12, weight: .semibold)
                    .foregroundStyle(Theme.amber)
                    .frame(width: 44, alignment: .leading)

                if !isAllDay {
                    HourMinuteMenuPicker(time: timeBinding)
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

            if strangerMatchingFeatureEnabled {
                Button {
                    entry.visibleToStrangers.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: entry.visibleToStrangers ? "checkmark.square.fill" : "square")
                        Text("この日は新しい人にも見せる")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(entry.visibleToStrangers ? Theme.amber : Theme.muted)
                }
                .buttonStyle(.plain)
            }

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
            if entry.location.trimmingCharacters(in: .whitespaces).isEmpty {
                entry.location = baseAirport
            }
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
