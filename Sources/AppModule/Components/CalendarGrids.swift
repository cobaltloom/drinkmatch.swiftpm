import SwiftUI

private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

/// One slot in a month grid: either a leading blank (before day 1) or an
/// actual day. A single `Hashable` cell type lets both grids below use one
/// `ForEach` over one flat array instead of two adjacent `ForEach`s (a
/// leading-blanks one plus a days one) whose counts each change size on
/// every month navigation — two Int-keyed `ForEach`s side by side inside a
/// `LazyVGrid` is a known source of stale/misaligned cell recycling when
/// their sizes shift between renders.
private enum MonthCell: Hashable {
    case blank(Int)
    case day(Int)
}

private func monthCells(year: Int, month: Int) -> [MonthCell] {
    let blanks = (0..<BoardCalendar.leadingBlankCount(year: year, month: month)).map { MonthCell.blank($0) }
    let days = (1...BoardCalendar.daysInMonth(year: year, month: month)).map { MonthCell.day($0) }
    return blanks + days
}

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
/// Takes `year`/`month` explicitly rather than reading `BoardCalendar`'s
/// app-wide default, since the schedule editor navigates its own month
/// independently of it — see ScheduleSetupView.
struct ScheduleCalendarPicker: View {
    var year: Int
    var month: Int
    var selectedDays: Set<Int>
    var onToggle: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            WeekdayHeaderRow()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(monthCells(year: year, month: month), id: \.self) { cell in
                    switch cell {
                    case .blank:
                        Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fill)
                    case .day(let day):
                        dayCell(day)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let isSelected = selectedDays.contains(day)
        let isPast = BoardCalendar.isPastDay(year: year, month: month, day: day)
        return Button {
            onToggle(day)
        } label: {
            Text("\(day)")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(isSelected ? Theme.amber : (isPast ? Theme.faint : Theme.muted))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .background(isSelected ? Theme.amberBackground : Theme.field)
                .opacity(isPast ? 0.4 : 1)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Theme.amber : Theme.fieldBorder)
                )
        }
        .buttonStyle(.plain)
        .disabled(isPast)
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
                ForEach(monthCells(year: BoardCalendar.year, month: BoardCalendar.month), id: \.self) { cell in
                    switch cell {
                    case .blank:
                        Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fill)
                    case .day(let day):
                        dayCell(day)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let entry = byDay[day]
        return Button {
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
