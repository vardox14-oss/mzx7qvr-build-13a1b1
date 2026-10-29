import Foundation

final class AutomationStore {
    private let defaults = UserDefaults.standard
    private var key = "dg_ios_automations_anon"

    func use(account: String) {
        let safe = account.isEmpty ? "anon" : account.lowercased()
        key = "dg_ios_automations_" + safe
    }

    func load() -> [ScheduledTask] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder.dg.decode([ScheduledTask].self, from: data) else {
            return defaultSampleTasks()
        }
        return list
    }

    func save(_ tasks: [ScheduledTask]) {
        if let data = try? JSONEncoder.dg.encode(tasks) {
            defaults.set(data, forKey: key)
        }
    }

    private func defaultSampleTasks() -> [ScheduledTask] {
        [
            ScheduledTask(
                title: "Veille tech & IA matinale",
                prompt: "Fais-moi un résumé condensé et percutant des 3 faits marquants de la tech et de l'intelligence artificielle ce matin.",
                modelSlug: "gemini-2.5-flash",
                frequency: .daily,
                hour: 8,
                minute: 30,
                isEnabled: true
            ),
            ScheduledTask(
                title: "Planification hebdomadaire",
                prompt: "Aide-moi à organiser mes priorités, mes objectifs et ma to-do list pour la semaine qui commence.",
                modelSlug: "gemini-2.5-flash",
                frequency: .weekly,
                hour: 9,
                minute: 0,
                dayOfWeek: 2, // Lundi
                isEnabled: false
            )
        ]
    }
}
