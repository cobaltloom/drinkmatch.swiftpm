import SwiftUI

/// Split-flap airport board inspired palette (navy × amber).
enum Theme {
    static let background = Color(hex: 0x0B1929)
    static let card = Color(hex: 0x142438)
    static let cardBorder = Color(hex: 0x24344A)
    static let field = Color(hex: 0x0F1E30)
    static let fieldBorder = Color(hex: 0x2E4058)
    static let divider = Color(hex: 0x1E2E42)

    static let amber = Color(hex: 0xFFB627)
    static let amberDim = Color(hex: 0xFAC775)
    static let amberBackground = Color(hex: 0x2A2210)
    static let amberText = Color(hex: 0x412402)

    static let text = Color(hex: 0xF5F3EE)
    static let muted = Color(hex: 0x8A97A8)
    static let faint = Color(hex: 0x5F6B7A)

    static let green = Color(hex: 0x4ADE80)
    static let greenBackground = Color(hex: 0x122A20)
    static let greenBorder = Color(hex: 0x1F4A38)
    static let red = Color(hex: 0xFF8A65)

    static let disabledBackground = Color(hex: 0x3A3A38)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Monospaced, slightly tracked-out text used for board-style readouts.
struct SplitFlapText: ViewModifier {
    var size: CGFloat
    var weight: Font.Weight = .regular

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: .monospaced))
            .tracking(0.4)
    }
}

extension View {
    func splitFlap(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(SplitFlapText(size: size, weight: weight))
    }
}

/// Primary amber "board" button used across the app for main calls to action.
struct BoardButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isDisabled ? Theme.disabledBackground : Theme.amber)
            .foregroundStyle(isDisabled ? Theme.faint : Theme.amberText)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Secondary outlined button (amber outline, transparent background).
struct BoardOutlineButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isDisabled ? Theme.faint : Theme.amber)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isDisabled ? Theme.fieldBorder : Theme.amber, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Neutral bordered button used for chrome actions (back, edit schedule, etc.)
struct BoardChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Theme.text)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Theme.fieldBorder, lineWidth: 1)
            )
    }
}

/// Minimal checkbox-style toggle so labels read left-to-right like a form
/// checkbox instead of a trailing iOS switch.
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Theme.amber : Theme.faint)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
