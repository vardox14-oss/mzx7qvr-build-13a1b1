import Foundation

enum TaskFrequency: String, Codable, CaseIterable {
    case daily = "Tous les jours"
    case weekdays = "En semaine (Lun-Ven)"
    case weekly = "Hebdomadaire"
    case once = "Une seule fois"

    var subtitle: String {
        switch self {
        case .daily: return "Chaque jour à l'heure fixée"
        case .weekdays: return "Du lundi au vendredi"
        case .weekly: return "Un jour précis par semaine"
        case .once: return "Rappel ponctuel"
        }
    }
}

struct ScheduledTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var prompt: String
    var modelSlug: String = "gemini-2.5-flash"
    var frequency: TaskFrequency = .daily
    var hour: Int = 9
    var minute: Int = 0
    var dayOfWeek: Int = 2 // Lundi par défaut (2 en Calendar)
    var isEnabled: Bool = true
    var created = Date()
    var lastRunDate: Date?
    var lastResult: String?

    var timeFormatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var scheduleSummary: String {
        switch frequency {
        case .daily: return "Tous les jours à \(timeFormatted)"
        case .weekdays: return "Lun-Ven à \(timeFormatted)"
        case .weekly:
            let days = ["", "Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
            let dayName = (dayOfWeek >= 1 && dayOfWeek < days.count) ? days[dayOfWeek] : "Lundi"
            return "Chaque \(dayName) à \(timeFormatted)"
        case .once: return "Rappel à \(timeFormatted)"
        }
    }
}
