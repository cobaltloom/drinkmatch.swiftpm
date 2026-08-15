import SwiftUI

/// Compact hour/minute picker in 5-minute increments, styled like the
/// app's other Menu-based pickers (e.g. birthYearMenu). Used instead of
/// DatePicker because SwiftUI's DatePicker has no equivalent to UIKit's
/// UIDatePicker.minuteInterval.
struct HourMinuteMenuPicker: View {
    @Binding var time: Date

    private var hourValue: Int {
        Calendar.current.component(.hour, from: time)
    }

    private var minuteValue: Int {
        let raw = Calendar.current.component(.minute, from: time)
        return (raw / 5) * 5
    }

    private func setHour(_ hour: Int) {
        time = Calendar.current.date(bySettingHour: hour, minute: minuteValue, second: 0, of: time) ?? time
    }

    private func setMinute(_ minute: Int) {
        time = Calendar.current.date(bySettingHour: hourValue, minute: minute, second: 0, of: time) ?? time
    }

    var body: some View {
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
}
