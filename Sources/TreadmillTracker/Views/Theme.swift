import SwiftUI

enum Theme {
    static let background = Color(red: 11 / 255, green: 13 / 255, blue: 12 / 255)
    static let surface = Color(red: 24 / 255, green: 28 / 255, blue: 25 / 255)
    static let elevated = Color(red: 39 / 255, green: 44 / 255, blue: 40 / 255)
    static let lime = Color(red: 200 / 255, green: 255 / 255, blue: 72 / 255)
    static let orange = Color(red: 255 / 255, green: 163 / 255, blue: 63 / 255)
    static let text = Color(red: 245 / 255, green: 247 / 255, blue: 242 / 255)
    static let secondary = Color(red: 164 / 255, green: 175 / 255, blue: 165 / 255)
    static let red = Color(red: 173 / 255, green: 38 / 255, blue: 49 / 255)
}

extension View {
    func sportCard(accent: Color? = nil) -> some View {
        self.padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accent ?? Theme.text.opacity(0.08), lineWidth: accent == nil ? 1 : 1.5)
            }
    }

    func sportForm() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

struct SportButtonStyle: ButtonStyle {
    var fill = Theme.lime
    var foreground = Theme.background

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SportMetric: View {
    let title: String
    let value: String
    var unit = ""
    var size: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: size, weight: .heavy)).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.caption.weight(.semibold)) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
