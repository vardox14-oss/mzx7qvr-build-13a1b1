import SwiftUI

enum Theme {
    static let bg = Color(red: 0.055, green: 0.055, blue: 0.063)
    static let surface = Color(red: 0.086, green: 0.086, blue: 0.098)
    static let surface2 = Color(red: 0.125, green: 0.125, blue: 0.14)
    static let stroke = Color.white.opacity(0.08)
    static let accent = Color(red: 0.898, green: 0.224, blue: 0.208)
    static let accent2 = Color(red: 1.0, green: 0.45, blue: 0.32)
    static let muted = Color.white.opacity(0.55)
    static let faint = Color.white.opacity(0.35)

    static let gradient = LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    func cardStyle(radius: CGFloat = 16) -> some View {
        self
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

func formatGems(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.locale = Locale(identifier: "fr_FR")
    return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
}
