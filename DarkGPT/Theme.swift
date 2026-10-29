import SwiftUI

enum Theme {
    /// True OLED Black for infinite contrast (style ChatGPT iOS).
    static let bg = Color.black
    /// Surface sombre pure pour barres et panneaux.
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.082)
    /// Surface 2 douce pour les bulles utilisateur et cartes (style graphite Apple).
    static let surface2 = Color(red: 0.165, green: 0.165, blue: 0.18)
    /// Surface 3 encore plus contrastée pour états actifs.
    static let surface3 = Color(red: 0.22, green: 0.22, blue: 0.24)
    /// Bordure micro-fine haute définition.
    static let stroke = Color.white.opacity(0.08)
    static let strokeActive = Color.white.opacity(0.18)

    /// Accent DarkGPT raffiné.
    static let accent = Color(red: 0.88, green: 0.22, blue: 0.24)
    static let accent2 = Color(red: 1.0, green: 0.46, blue: 0.35)

    /// Textes à hiérarchie optique parfaite.
    static let primary = Color.white
    static let muted = Color.white.opacity(0.65)
    static let faint = Color.white.opacity(0.38)

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
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
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

enum Season {
    static var forceHalloween = false
    static var isHalloween: Bool {
        if forceHalloween { return true }
        return Calendar.current.component(.month, from: Date()) == 10
    }
    static let pumpkin = Color(red: 1.0, green: 0.46, blue: 0.09)
}
