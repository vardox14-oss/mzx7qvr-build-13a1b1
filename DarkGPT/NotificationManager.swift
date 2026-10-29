import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleTask(_ task: ScheduledTask) {
        guard task.isEnabled else {
            cancelTask(task)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "DarkGPT · Tâche planifiée"
        content.subtitle = task.title
        content.body = "Touche pour lancer la tâche et obtenir ta réponse."
        content.sound = .default
        content.userInfo = ["taskId": task.id.uuidString, "prompt": task.prompt, "model": task.modelSlug]

        var dateComponents = DateComponents()
        dateComponents.hour = task.hour
        dateComponents.minute = task.minute

        var repeats = true
        switch task.frequency {
        case .daily:
            break
        case .weekdays:
            // Pour weekdays, planifier pour chaque jour 2..6
            for day in 2...6 {
                var c = dateComponents
                c.weekday = day
                let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
                let req = UNNotificationRequest(identifier: "task_\(task.id.uuidString)_\(day)", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
            }
            return
        case .weekly:
            dateComponents.weekday = task.dayOfWeek
        case .once:
            repeats = false
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: "task_\(task.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelTask(_ task: ScheduledTask) {
        var ids = ["task_\(task.id.uuidString)"]
        for day in 2...6 {
            ids.append("task_\(task.id.uuidString)_\(day)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
