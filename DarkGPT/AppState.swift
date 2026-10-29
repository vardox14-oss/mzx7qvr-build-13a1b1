import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case loading, loggedOut, loggedIn }

    @Published var phase: Phase = .loading
    @Published var user: UserProfile?
    @Published var models: [AIModel] = []
    @Published var conversations: [Conversation] = []
    @Published var projects: [Project] = []
    @Published var tasks: [ScheduledTask] = []
    @Published var selectedModelSlug: String = "gemini-2.5-flash"
    @Published var loadError: String?

    private let store = ConversationStore()
    private let projectStore = ProjectStore()
    private let automationStore = AutomationStore()

    var chatModels: [AIModel] { models.filter { $0.isChatModel } }
    var plan: String { user?.plan ?? "free" }

    func selectedModel() -> AIModel? {
        chatModels.first { $0.slug == selectedModelSlug } ?? chatModels.first
    }

    func project(for id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    var allArtifacts: [Artifact] {
        var list: [Artifact] = []
        for c in conversations {
            for m in c.messages where m.role == .assistant {
                let extracted = ArtifactExtractor.extract(from: m.content, messageId: m.id)
                list.append(contentsOf: extracted)
            }
        }
        return list
    }

    func bootstrap() async {
        phase = .loading
        do {
            let profile = try await APIClient.shared.me()
            await finishLogin(profile)
        } catch {
            phase = .loggedOut
        }
    }

    func finishLogin(_ profile: UserProfile) async {
        user = profile
        store.use(account: profile.email)
        projectStore.use(account: profile.email)
        automationStore.use(account: profile.email)

        conversations = store.load()
        projects = projectStore.load()
        tasks = automationStore.load()

        await loadModels()
        phase = .loggedIn
    }

    func refreshUser() async {
        if let profile = try? await APIClient.shared.me() { user = profile }
    }

    func loadModels() async {
        do {
            let list = try await APIClient.shared.models()
            if !list.isEmpty {
                models = list
                if selectedModel() == nil, let first = chatModels.first { selectedModelSlug = first.slug }
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func logout() async {
        await APIClient.shared.logout()
        user = nil
        conversations = []
        projects = []
        tasks = []
        phase = .loggedOut
    }

    // MARK: - Conversations

    func persist() { store.save(conversations) }

    func upsert(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        conversations.sort { ($0.pinned ? 1 : 0, $0.updated) > ($1.pinned ? 1 : 0, $1.updated) }
        persist()
    }

    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        persist()
    }

    func togglePin(_ conversation: Conversation) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].pinned.toggle()
        conversations.sort { ($0.pinned ? 1 : 0, $0.updated) > ($1.pinned ? 1 : 0, $1.updated) }
        persist()
    }

    // MARK: - Projects

    func persistProjects() { projectStore.save(projects) }

    func upsertProject(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            projects.insert(project, at: 0)
        }
        projects.sort { $0.updated > $1.updated }
        persistProjects()
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        persistProjects()
    }

    // MARK: - Automations / Tasks

    func persistTasks() { automationStore.save(tasks) }

    func upsertTask(_ task: ScheduledTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        } else {
            tasks.insert(task, at: 0)
        }
        persistTasks()
    }

    func deleteTask(_ task: ScheduledTask) {
        NotificationManager.shared.cancelTask(task)
        tasks.removeAll { $0.id == task.id }
        persistTasks()
    }

    func setGems(_ gems: Double?) {
        guard let gems, var u = user else { return }
        u.gems = gems
        user = u
    }
}
