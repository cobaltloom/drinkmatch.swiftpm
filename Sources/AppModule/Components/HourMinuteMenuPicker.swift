import SwiftUI

/// Compact hour/minute picker in 5-minute increments, presented as a
/// scrollable wheel popover like the native Calendar app's time picker.
/// Used instead of DatePicker because SwiftUI's DatePicker has no
/// equivalent to UIKit's UIDatePicker.minuteInterval.
struct HourMinuteMenuPicker: View {
    @Binding var time: Date
    @State private var isPresented = false

    private var hourValue: Int {
        Calendar.current.component(.hour, from: time)
    }

    private var minuteValue: Int {
        let raw = Calendar.current.component(.minute, from: time)
        return (raw / 5) * 5
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { hourValue },
            set: { newHour in
                time = Calendar.current.date(bySettingHour: newHour, minute: minuteValue, second: 0, of: time) ?? time
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minuteValue },
            set: { newMinute in
                time = Calendar.current.date(bySettingHour: hourValue, minute: newMinute, second: 0, of: time) ?? time
            }
        )
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text(String(format: "%02d:%02d", hourValue, minuteValue))
                .splitFlap(13)
                .foregroundStyle(Theme.amber)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            HStack(spacing: 0) {
                Picker("時", selection: hourBinding) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)

                Picker("分", selection: minuteBinding) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(width: 160, height: 180)
            .presentationCompactAdaptation(.popover)
        }
    }
}
