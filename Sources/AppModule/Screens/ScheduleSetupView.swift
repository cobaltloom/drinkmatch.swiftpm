import SwiftUI

/// Off-day + stay-airport + free-from-time registration screen, used both
/// for first-run setup and for later edits from the main screen.
///
/// Defaults to `initialYear`/`initialMonth` (the caller passes
/// `AppStore.scheduleYear`/`.scheduleMonth`, itself seeded from
/// `BoardCalendar`'s 25th-of-the-month-rolls-to-next-month default) but
/// navigates its own local month independently of that app-wide default —
/// see BoardCalendar's header comment for why the two are kept separate.
struct ScheduleSetupView: View {
    var friends: [Person]
    var initialEntries: [StayEntry]
    var initialYear: Int
    var initialMonth: Int
    var onDone: ([StayEntry], Int, Int) -> Void
    var onMonthChange: (Int, Int) async -> [StayEntry]

    @State private var entries: [StayEntry]
    @State private var selectedDays: Set<Int>
    @State private var year: Int
    @State private var month: Int
    @State private var isLoadingMonth = false

    init(
        friends: [Person],
        initialEntries: [StayEntry],
        initialYear: Int,
        initialMonth: Int,
        onDone: @escaping ([StayEntry], Int, Int) -> Void,
        onMonthChange: @escaping (Int, Int) async -> [StayEntry]
    ) {
        self.friends = friends
        self.initialEntries = initialEntries
        self.initialYear = initialYear
        self.initialMonth = initialMonth
        self.onDone = onDone
        self.onMonthChange = onMonthChange
        _entries = State(initialValue: initialEntries.sorted { $0.day < $1.day })
        _selectedDays = State(initialValue: Set(initialEntries.map(\.day)))
        _year = State(initialValue: initialYear)
        _month = State(initialValue: initialMonth)
    }

    private var canSubmit: Bool {
        !entries.isEmpty && entries.allSatisfy { !$0.location.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        BoardScreenContainer {
            Text("SCHEDULE — ステイ先と空き時間").splitFlap(18, weight: .bold).foregroundStyle(Theme.amber)
            Text("オフの日をタップし、ステイ先(滞在都市)と何時から動けるかを入力してください。特定の知り合いにだけ見せたくない日は、各エントリの「非公開にする」から設定できます。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 14)

            monthNavigator
                .padding(.bottom, 8)

            BoardCard {
                ScheduleCalendarPicker(year: year, month: month, selectedDays: selectedDays, onToggle: toggleDay)
                    .opacity(isLoadingMonth ? 0.4 : 1)
                    .disabled(isLoadingMonth)
            }
            .padding(.bottom, 14)

            if !entries.isEmpty {
                BoardCard {
                    Text("日付 / ステイ先 / 動ける時間")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                        .padding(.bottom, 8)
                    ForEach($entries) { $entry in
                        StayEntryEditorView(entry: $entry, friends: friends, onRemove: { toggleDay(entry.day) })
                    }
                }
                .padding(.bottom, 14)
            }

            Button("この予定で始める") {
                onDone(entries, year, month)
            }
            .buttonStyle(BoardButtonStyle(isDisabled: !canSubmit))
            .disabled(!canSubmit)

            if !entries.isEmpty && !canSubmit {
                Text("選択した日はすべてステイ先を入力してください。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.red)
                    .padding(.top, 8)
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                Task { await changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(isLoadingMonth)

            Spacer()

            Text("\(year)年\(month)月")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.amber)

            Spacer()

            Button {
                Task { await changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isLoadingMonth)
        }
        .foregroundStyle(Theme.muted)
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
            entries.removeAll { $0.day == day }
        } else {
            selectedDays.insert(day)
            entries.append(StayEntry(day: day, location: "", from: "19:00", hiddenFrom: []))
            entries.sort { $0.day < $1.day }
        }
    }

    private func changeMonth(by delta: Int) async {
        isLoadingMonth = true
        defer { isLoadingMonth = false }

        var newMonth = month + delta
        var newYear = year
        if newMonth < 1 {
            newMonth = 12
            newYear -= 1
        } else if newMonth > 12 {
            newMonth = 1
            newYear += 1
        }

        let freshEntries = await onMonthChange(newYear, newMonth)
        year = newYear
        month = newMonth
        entries = freshEntries.sorted { $0.day < $1.day }
        selectedDays = Set(freshEntries.map(\.day))
    }
}
