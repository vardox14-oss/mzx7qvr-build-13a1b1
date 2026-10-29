import SwiftUI

/// Slide-in drawer: new chat, quick power tools (Projets, Automations, Artefacts), search, history grouped by date, account.
struct SidebarView: View {
    @EnvironmentObject var app: AppState
    let currentID: String
    var onNewChat: () -> Void
    var onOpen: (Conversation) -> Void
    var onOpenProjects: () -> Void
    var onOpenAutomations: () -> Void
    var onOpenArtifacts: () -> Void
    var onAccount: () -> Void
    @State private var query = ""

    private var filtered: [Conversation] {
        query.isEmpty ? app.conversations
            : app.conversations.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var sections: [(String, [Conversation])] {
        let cal = Calendar.current
        var pinned: [Conversation] = [], today: [Conversation] = [], yesterday: [Conversation] = []
        var week: [Conversation] = [], older: [Conversation] = []
        for c in filtered {
            if c.pinned { pinned.append(c) }
            else if cal.isDateInToday(c.updated) { today.append(c) }
            else if cal.isDateInYesterday(c.updated) { yesterday.append(c) }
            else if let d = cal.dateComponents([.day], from: c.updated, to: Date()).day, d < 7 { week.append(c) }
            else { older.append(c) }
        }
        return [("Épinglées", pinned), ("Aujourd'hui", today), ("Hier", yesterday),
                ("7 derniers jours", week), ("Plus ancien", older)].filter { !$0.1.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            powerToolsBar
            search
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if app.conversations.isEmpty {
                        Text("Tes conversations apparaîtront ici.")
                            .font(.footnote).foregroundStyle(Theme.faint)
                            .padding(.horizontal, 12).padding(.top, 20)
                    }
                    ForEach(sections, id: \.0) { title, items in
                        Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.faint)
                            .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 4)
                        ForEach(items) { convo in row(convo) }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
            }
            account
        }
        .background(Theme.surface.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("Logo").resizable().scaledToFit().frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("DarkGPT").font(.headline).foregroundStyle(.white)
            Spacer()
            Button { Haptics.tap(); onNewChat() } label: {
                Image(systemName: "square.and.pencil").font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white).frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
    }

    private var powerToolsBar: some View {
        VStack(spacing: 4) {
            powerToolRow(icon: "folder.fill", title: "Projets", count: app.projects.count, color: Theme.accent2) {
                onOpenProjects()
            }
            powerToolRow(icon: "bolt.badge.clock.fill", title: "Tâches & Automations", count: app.tasks.filter { $0.isEnabled }.count, color: .orange) {
                onOpenAutomations()
            }
            powerToolRow(icon: "sparkles", title: "Studio d'Artefacts", count: app.allArtifacts.count, color: .cyan) {
                onOpenArtifacts()
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private func powerToolRow(icon: String, title: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.surface2, in: Capsule())
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 10).frame(height: 34)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.footnote).foregroundStyle(Theme.faint)
            TextField("", text: $query, prompt: Text("Rechercher une discussion…").foregroundColor(Theme.faint))
                .foregroundStyle(.white).font(.subheadline)
        }
        .padding(.horizontal, 12).frame(height: 38)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 14).padding(.bottom, 4)
    }

    private func row(_ convo: Conversation) -> some View {
        let active = convo.id == currentID
        let project = app.project(for: convo.projectId)
        return Button { onOpen(convo) } label: {
            HStack(spacing: 8) {
                if convo.pinned {
                    Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(Theme.accent2)
                }
                if let project {
                    Image(systemName: project.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(project.color)
                }
                Text(convo.title).font(.subheadline).foregroundStyle(.white.opacity(active ? 1 : 0.85)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(active ? Theme.surface2 : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button { app.togglePin(convo) } label: { Label(convo.pinned ? "Désépingler" : "Épingler", systemImage: "pin") }
            Button(role: .destructive) { app.delete(convo) } label: { Label("Supprimer", systemImage: "trash") }
        }
    }

    private var account: some View {
        Button { Haptics.tap(); onAccount() } label: {
            HStack(spacing: 10) {
                AsyncImage(url: app.user?.avatar) { img in img.resizable().scaledToFill() }
                    placeholder: { Text(String(app.user?.name.prefix(1) ?? "D")).font(.subheadline.weight(.bold)).foregroundStyle(.white) }
                    .frame(width: 34, height: 34).background(Theme.accent.opacity(0.8)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.user?.name ?? "Utilisateur").font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Text("\(app.user?.planLabel ?? "Gratuit") · \(formatGems(app.user?.gems ?? 0)) gems")
                        .font(.caption2).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.surface)
            .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
        }
    }
}
