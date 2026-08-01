import SwiftUI

/// Lets the user pick one of their own stay slots, then invite every
/// candidate who shares that exact day + airport as a group.
struct GroupOrganizerView: View {
    var mySchedule: [StayEntry]
    var candidates: [Person]
    var showFullName: Bool
    /// Pre-computed by the store via `get_match_overlap`, one entry per
    /// candidate id — see the note on PersonCardView.overlap.
    var overlapByCandidateID: [UUID: [StayOverlap]]
    var onSubmit: (Int, String, [Person], Bool) -> Void

    @State private var slotDay: Int?
    @State private var selectedIDs: Set<UUID> = []
    @State private var autoAccept = false

    private var slotOptions: [StayEntry] {
        mySchedule.filter { !$0.location.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var slot: StayEntry? { slotOptions.first { $0.day == slotDay } }

    private var matchingCandidates: [Person] {
        guard let slot else { return [] }
        return candidates.filter { candidate in
            let overlap = overlapByCandidateID[candidate.id] ?? []
            return overlap.contains { $0.day == slot.day && $0.location == slot.location }
        }
    }

    var body: some View {
        if slotOptions.isEmpty {
            Text("グループを作るには、まず自分のスケジュールにステイ先を登録してください。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                BoardCard {
                    Text("どの予定でグループを組みますか")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .padding(.bottom, 6)
                    Picker("", selection: $slotDay) {
                        ForEach(slotOptions) { entry in
                            Text("\(fmtDate(entry.day)) — \(airportLabel(entry.location))").tag(entry.day as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.text)
                }

                if matchingCandidates.isEmpty {
                    Text("この日程・ステイ先が重なる候補がいません。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    ForEach(matchingCandidates) { candidate in
                        GroupCandidateRowView(
                            person: candidate,
                            showFullName: showFullName,
                            selected: selectedIDs.contains(candidate.id),
                            onToggle: { toggle(candidate.id) }
                        )
                    }

                    Toggle(isOn: $autoAccept) {
                        Text("全員の誘いを自動承諾でOKにする(承諾ステップを省略)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    .toggleStyle(.checkbox)

                    Button("\(selectedIDs.count)人をまとめて誘う") { submit() }
                        .buttonStyle(BoardButtonStyle(isDisabled: selectedIDs.isEmpty))
                        .disabled(selectedIDs.isEmpty)
                }
            }
            .onAppear { if slotDay == nil { slotDay = slotOptions.first?.day } }
            .onChange(of: slotDay) { selectedIDs = [] }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func submit() {
        guard let slot else { return }
        let members = matchingCandidates.filter { selectedIDs.contains($0.id) }
        guard !members.isEmpty else { return }
        onSubmit(slot.day, slot.location, members, autoAccept)
        selectedIDs = []
    }
}
