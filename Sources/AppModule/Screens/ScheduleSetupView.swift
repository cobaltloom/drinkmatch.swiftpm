import SwiftUI

/// Off-day + stay-airport + free-from-time registration screen, used both
/// for first-run setup and for later edits from the main screen.
struct ScheduleSetupView: View {
    var friends: [Person]
    var initialEntries: [StayEntry]
    var onDone: ([StayEntry]) -> Void

    @State private var entries: [StayEntry]
    @State private var selectedDays: Set<Int>

    init(friends: [Person], initialEntries: [StayEntry], onDone: @escaping ([StayEntry]) -> Void) {
        self.friends = friends
        self.initialEntries = initialEntries
        self.onDone = onDone
        _entries = State(initialValue: initialEntries.sorted { $0.day < $1.day })
        _selectedDays = State(initialValue: Set(initialEntries.map(\.day)))
    }

    private var canSubmit: Bool {
        !entries.isEmpty && entries.allSatisfy { !$0.location.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        BoardScreenContainer {
            Text("SCHEDULE — ステイ先と空き時間").splitFlap(18, weight: .bold).foregroundStyle(Theme.amber)
            Text("\(BoardCalendar.year)年\(BoardCalendar.month)月のオフの日をタップし、ステイ先(滞在都市)と何時から動けるかを入力してください。特定の知り合いにだけ見せたくない日は、各エントリの「非公開にする」から設定できます。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 14)

            BoardCard {
                ScheduleCalendarPicker(selectedDays: selectedDays, onToggle: toggleDay)
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
                onDone(entries)
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
}
