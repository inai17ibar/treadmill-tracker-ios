import SwiftUI

/// Sporty look: black canvas, volt accent, heavy condensed italic numbers.
enum Theme {
    static let volt = Color(red: 0.84, green: 1.0, blue: 0.0)
    static let background = Color.black
    static let surface = Color(white: 0.11)
    static let surfaceHigh = Color(white: 0.18)
    static let secondaryText = Color(white: 0.6)
    static let stop = Color(red: 0.98, green: 0.24, blue: 0.2)

    /// Big metric numbers.
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed).italic()
    }

    /// Screen and section headlines.
    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed).italic()
    }
}

/// Small uppercase-style caption above or below a number.
struct MetricLabel: View {
    let text: String
    var color: Color = Theme.secondaryText

    init(_ text: String, color: Color = Theme.secondaryText) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Capsule chips used as a segmented control.
struct ChipPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var foreground: Color = .white
    var accent: Color = Theme.volt
    var accentText: Color = .black
    let label: (Value) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(selected ? accentText : foreground)
                        .background(selected ? accent : foreground.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Shrinks slightly when pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
