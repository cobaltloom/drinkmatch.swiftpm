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
    var onRemove: () -> Void

    @State private var showingHideOptions = false
    /// Remembers the last specific time so unchecking "一日中OK" restores it
    /// instead of leaving the picker at midnight.
    @State private var savedTime = "19:00"

    private var isAllDay: Bool { entry.from == "00:00" }

    private var hourValue: Int {
        Int(entry.from.split(separator: ":").first ?? "") ?? 19
    }

    /// Rounded down to the nearest 5 minutes — free-from times don't need
    /// finer granularity than that, and it keeps the picker list short.
    private var minuteValue: Int {
        let parts = entry.from.split(separator: ":")
        guard parts.count > 1, let raw = Int(parts[1]) else { return 0 }
        return (raw / 5) * 5
    }

    private func setHour(_ hour: Int) {
        entry.from = String(format: "%02d:%02d", hour, minuteValue)
    }

    private func setMinute(_ minute: Int) {
        entry.from = String(format: "%02d:%02d", hourValue, minute)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(dateLabel(month: month, day: entry.day))
                    .splitFlap(12, weight: .semibold)
                    .foregroundStyle(Theme.amber)
                    .frame(width: 44, alignment: .leading)

                if !isAllDay {
                    timePicker
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

    private var timePicker: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(0..<24, id: \.self) { hour in
                    Button(String(format: "%02d", hour)) { setHour(hour) }
                }
            } label: {
                Text(String(format: "%02d", hourValue))
                    .splitFlap(13)
                    .foregroundStyle(Theme.amber)
            }

            Text(":").foregroundStyle(Theme.muted)

            Menu {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                    Button(String(format: "%02d", minute)) { setMinute(minute) }
                }
            } label: {
                Text(String(format: "%02d", minuteValue))
                    .splitFlap(13)
                    .foregroundStyle(Theme.amber)
            }
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
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
