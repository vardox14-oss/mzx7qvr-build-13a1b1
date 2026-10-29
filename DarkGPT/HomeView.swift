import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var conversation = Conversation(id: Conversation.newID(), title: "Nouvelle conversation", model: "", updated: Date())
    @State private var showSidebar = false
    @State private var showModels = false
    @State private var showSettings = false
    @State private var showProjects = false
    @State private var showAutomations = false
    @State private var showArtifactGallery = false
    @State private var showExportSheet = false
    @State private var exportText = ""

    private var sidebarWidth: CGFloat { min(UIScreen.main.bounds.width * 0.84, 340) }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                ChatView(conversation: $conversation)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbar }
                    .toolbarBackground(Theme.bg, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .offset(x: showSidebar ? sidebarWidth : 0)
            .allowsHitTesting(!showSidebar)

            if showSidebar {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .offset(x: sidebarWidth)
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            SidebarView(
                currentID: conversation.id,
                onNewChat: { newChat(); close() },
                onOpen: { open($0) },
                onOpenProjects: { close(); showProjects = true },
                onOpenAutomations: { close(); showAutomations = true },
                onOpenArtifacts: { close(); showArtifactGallery = true },
                onAccount: { close(); showSettings = true }
            )
            .frame(width: sidebarWidth)
            .offset(x: showSidebar ? 0 : -sidebarWidth)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: showSidebar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { v in
                let horizontal = abs(v.translation.width) > abs(v.translation.height) * 1.5
                guard horizontal else { return }
                if !showSidebar && v.translation.width > 70 && v.startLocation.x < 60 { openSidebar() }
                else if showSidebar && v.translation.width < -70 { close() }
            }
        )
        .sheet(isPresented: $showModels) {
            ModelPickerView(selected: $app.selectedModelSlug).presentationDetents([.large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showProjects) {
            ProjectsView { project in
                showProjects = false
                startProjectChat(project)
            }
        }
        .sheet(isPresented: $showAutomations) {
            AutomationsView { task in
                showAutomations = false
                runScheduledTask(task)
            }
        }
        .sheet(isPresented: $showArtifactGallery) {
            ArtifactGalleryView()
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(activityItems: [exportText])
        }
        .task { await app.refreshUser() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { openSidebar() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
            }
        }

        ToolbarItem(placement: .principal) {
            Button { Haptics.tap(); showModels = true } label: {
                HStack(spacing: 5) {
                    Text(app.selectedModel()?.name ?? "DarkGPT")
                        .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 200)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 6) {
                Button { Haptics.tap(); newChat() } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                }

                Menu {
                    Button {
                        exportCurrentChat()
                    } label: {
                        Label("Exporter la conversation", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showArtifactGallery = true
                    } label: {
                        Label("Studio d'Artefacts & Code", systemImage: "sparkles")
                    }

                    Button {
                        showProjects = true
                    } label: {
                        Label("Projets & Contexte", systemImage: "folder")
                    }

                    Button {
                        showAutomations = true
                    } label: {
                        Label("Tâches & Automations", systemImage: "bolt.badge.clock")
                    }

                    Divider()

                    Button(role: .destructive) {
                        clearCurrentChat()
                    } label: {
                        Label("Vider les messages", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    private func openSidebar() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Haptics.tap(); showSidebar = true
    }
    private func close() { showSidebar = false }

    private func open(_ convo: Conversation) {
        if !conversation.messages.isEmpty && conversation.id != convo.id { app.upsert(conversation) }
        conversation = convo
        if let m = app.chatModels.first(where: { $0.slug == convo.model }) { app.selectedModelSlug = m.slug }
        close()
    }

    private func newChat() {
        if !conversation.messages.isEmpty { app.upsert(conversation) }
        conversation = Conversation(id: Conversation.newID(), title: "Nouvelle conversation", model: app.selectedModelSlug, updated: Date())
    }

    private func startProjectChat(_ project: Project) {
        if !conversation.messages.isEmpty { app.upsert(conversation) }
        conversation = Conversation(
            id: Conversation.newID(),
            title: "Projet : \(project.name)",
            model: app.selectedModelSlug,
            updated: Date(),
            projectId: project.id
        )
    }

    private func runScheduledTask(_ task: ScheduledTask) {
        if !conversation.messages.isEmpty { app.upsert(conversation) }
        if let m = app.chatModels.first(where: { $0.slug == task.modelSlug }) {
            app.selectedModelSlug = m.slug
        }
        conversation = Conversation(
            id: Conversation.newID(),
            title: task.title,
            model: task.modelSlug,
            updated: Date()
        )
    }

    private func exportCurrentChat() {
        var output = "# \(conversation.title)\nModèle: \(conversation.model)\nDate: \(conversation.updated)\n\n"
        for m in conversation.messages {
            output += "### \(m.role == .user ? "Utilisateur" : "DarkGPT")\n"
            output += m.content + "\n\n"
        }
        exportText = output
        showExportSheet = true
    }

    private func clearCurrentChat() {
        conversation.messages = []
        app.upsert(conversation)
        Haptics.tap()
    }
}
