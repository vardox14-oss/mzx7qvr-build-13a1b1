import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case loading, loggedOut, loggedIn }

    @Published var phase: Phase = .loading
    @Published var user: UserProfile?
    @Published var models: [AIModel] = []
    @Published var conversations: [Conversation] = []
    @Published var selectedModelSlug: String = "gemini-2.5-flash"
    @Published var loadError: String?

    private let store = ConversationStore()

    var chatModels: [AIModel] { models.filter { $0.isChatModel } }
    var plan: String { user?.plan ?? "free" }

    func selectedModel() -> AIModel? {
        chatModels.first { $0.slug == selectedModelSlug } ?? chatModels.first
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
        conversations = store.load()
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
        phase = .loggedOut
    }

    // MARK: Conversations

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

    func setGems(_ gems: Double?) {
        guard let gems, var u = user else { return }
        u.gems = gems
        user = u
    }
}
