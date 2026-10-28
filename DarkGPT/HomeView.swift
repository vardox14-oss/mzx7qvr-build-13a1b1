import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var conversation = Conversation(id: Conversation.newID(), title: "Nouvelle conversation", model: "", updated: Date())
    @State private var showConversations = false
    @State private var showModels = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ChatView(conversation: $conversation)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .toolbarBackground(Theme.bg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showConversations) {
            ConversationsView(current: $conversation) { showConversations = false }
        }
        .sheet(isPresented: $showModels) {
            ModelPickerView(selected: $app.selectedModelSlug)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().presentationDetents([.medium, .large])
        }
        .task { await app.refreshUser() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { Haptics.tap(); showConversations = true } label: {
                Image(systemName: "line.3.horizontal")
            }
        }
        ToolbarItem(placement: .principal) {
            Button { Haptics.tap(); showModels = true } label: {
                HStack(spacing: 6) {
                    Text(app.selectedModel()?.name ?? "Modèle").font(.subheadline.weight(.semibold)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.surface2, in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 14) {
                Button { Haptics.tap(); newChat() } label: { Image(systemName: "square.and.pencil") }
                Button { Haptics.tap(); showSettings = true } label: {
                    GemPill(gems: app.user?.gems ?? 0)
                }
            }
        }
    }

    private func newChat() {
        if !conversation.messages.isEmpty { app.upsert(conversation) }
        conversation = Conversation(id: Conversation.newID(), title: "Nouvelle conversation", model: app.selectedModelSlug, updated: Date())
    }
}

struct GemPill: View {
    let gems: Double
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill").font(.caption2).foregroundStyle(Theme.accent2)
            Text(formatGems(gems)).font(.caption.weight(.bold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.surface2, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
    }
}
