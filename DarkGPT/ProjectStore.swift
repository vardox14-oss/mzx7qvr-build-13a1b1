import Foundation

final class ProjectStore {
    private let defaults = UserDefaults.standard
    private var key = "dg_ios_projects_anon"

    func use(account: String) {
        let safe = account.isEmpty ? "anon" : account.lowercased()
        key = "dg_ios_projects_" + safe
    }

    func load() -> [Project] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder.dg.decode([Project].self, from: data) else {
            // Projets par défaut pour démarrer directement
            return defaultSampleProjects()
        }
        return list.sorted { $0.updated > $1.updated }
    }

    func save(_ projects: [Project]) {
        if let data = try? JSONEncoder.dg.encode(projects) {
            defaults.set(data, forKey: key)
        }
    }

    private func defaultSampleProjects() -> [Project] {
        [
            Project(
                name: "Développement iOS",
                description: "Architecture Swift, SwiftUI, bonnes pratiques et optimisation.",
                icon: "swift",
                colorHex: "#FF5722",
                customInstructions: "Tu es un architecte iOS senior expert en Swift 5/6 et SwiftUI. Fournis du code idiomatique, concis, typé et moderne avec explications claires.",
                files: [
                    ProjectFile(
                        name: "CodingGuidelines.md",
                        content: "- Préférer des vues SwiftUI modulaires et petites.\n- Utiliser @EnvironmentObject pour l'état partagé.\n- Gérer la cancellation des Tasks asynchrones."
                    )
                ]
            ),
            Project(
                name: "Assistant Rédaction",
                description: "Articles, emails professionnels et synthèses percutantes.",
                icon: "doc.text.fill",
                colorHex: "#3F51B5",
                customInstructions: "Adopte un ton professionnel, clair, percutant et élégant. Structure toujours tes réponses avec des puces et des titres clairs.",
                files: []
            )
        ]
    }
}
