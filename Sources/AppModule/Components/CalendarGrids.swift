import SwiftUI

private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

/// Weekday header row shared by both calendar grids below.
private struct WeekdayHeaderRow: View {
    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(BoardCalendar.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Month grid used to pick which off-days to register a schedule for.
struct ScheduleCalendarPicker: View {
    var selectedDays: Set<Int>
    var onToggle: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            WeekdayHeaderRow()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<BoardCalendar.leadingBlankCount, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                ForEach(1...BoardCalendar.daysInMonth, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        onToggle(day)
                    } label: {
                        Text("\(day)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(isSelected ? Theme.amber : Theme.muted)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .background(isSelected ? Theme.amberBackground : Theme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? Theme.amber : Theme.fieldBorder)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Read-only month grid highlighting another person's registered stay days
/// in green; tapping a highlighted day picks it (e.g. to send a proposal).
struct ReadOnlyStayCalendar: View {
    var stays: [StayEntry]
    var onPick: (StayEntry) -> Void

    private var byDay: [Int: StayEntry] {
        Dictionary(uniqueKeysWithValues: stays.map { ($0.day, $0) })
    }

    var body: some View {
        VStack(spacing: 4) {
            WeekdayHeaderRow()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<BoardCalendar.leadingBlankCount, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                ForEach(1...BoardCalendar.daysInMonth, id: \.self) { day in
                    let entry = byDay[day]
                    Button {
                        if let entry { onPick(entry) }
                    } label: {
                        Text("\(day)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(entry != nil ? Theme.green : Color(hex: 0x3A4656))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .background(entry != nil ? Theme.greenBackground : Theme.field)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(entry != nil ? Theme.green : Theme.fieldBorder)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(entry == nil)
                    .accessibilityLabel(entry.map { "\(airportLabel($0.location)) \($0.from)〜" } ?? "")
                }
            }
        }
    }
}
