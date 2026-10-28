import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject var app: AppState
    @Binding var current: Conversation
    var onPick: () -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [Conversation] {
        query.isEmpty ? app.conversations
            : app.conversations.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if app.conversations.isEmpty { empty }
                else {
                    List {
                        ForEach(filtered) { convo in
                            Button { open(convo) } label: { row(convo) }
                                .listRowBackground(Theme.surface)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { app.delete(convo) } label: { Label("Supprimer", systemImage: "trash") }
                                    Button { app.togglePin(convo) } label: { Label("Épingler", systemImage: "pin") }.tint(Theme.accent2)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $query, prompt: "Rechercher")
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newChat() } label: { Image(systemName: "square.and.pencil") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func row(_ convo: Conversation) -> some View {
        HStack(spacing: 10) {
            if convo.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Theme.accent2) }
            VStack(alignment: .leading, spacing: 3) {
                Text(convo.title).font(.subheadline.weight(.medium)).foregroundStyle(.white).lineLimit(1)
                Text(convo.updated, style: .date).font(.caption2).foregroundStyle(Theme.faint)
            }
            Spacer()
            if convo.id == current.id { Circle().fill(Theme.accent).frame(width: 7, height: 7) }
        }
        .padding(.vertical, 2)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle).foregroundStyle(Theme.faint)
            Text("Aucune conversation").foregroundStyle(Theme.muted)
        }
    }

    private func open(_ convo: Conversation) {
        if !current.messages.isEmpty && current.id != convo.id { app.upsert(current) }
        current = convo
        onPick()
    }

    private func newChat() {
        if !current.messages.isEmpty { app.upsert(current) }
        current = Conversation(id: Conversation.newID(), title: "Nouvelle conversation", model: app.selectedModelSlug, updated: Date())
        onPick()
    }
}
