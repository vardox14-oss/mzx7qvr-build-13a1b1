import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var app: AppState
    var onSelectProjectChat: (Project) -> Void

    @State private var showingNewProject = false
    @State private var selectedProject: Project?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBanner

                    if app.projects.isEmpty {
                        emptyView
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(app.projects) { project in
                                projectCard(project)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Projets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingNewProject) {
                ProjectEditorSheet(project: nil) { newP in
                    app.upsertProject(newP)
                }
            }
            .sheet(item: $selectedProject) { proj in
                ProjectDetailView(project: proj, onStartChat: { p in
                    selectedProject = nil
                    onSelectProjectChat(p)
                })
            }
        }
    }

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.title3)
                    .foregroundStyle(Theme.accent2)
                Text("Espaces de travail & Contexte")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text("Crée des projets avec des instructions sur-mesure et des fichiers de connaissances que l'IA consulte à chaque question.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .cardStyle(radius: 18)
    }

    private func projectCard(_ project: Project) -> some View {
        Button {
            Haptics.tap()
            selectedProject = project
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(project.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: project.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(project.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Label("\(project.files.count) fichier(s)", systemImage: "doc")
                            .font(.caption2)
                            .foregroundStyle(Theme.faint)
                        if !project.customInstructions.isEmpty {
                            Label("Instructions actives", systemImage: "text.badge.checkmark")
                                .font(.caption2)
                                .foregroundStyle(Theme.accent2)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.faint)
            }
            .padding(14)
            .cardStyle(radius: 16)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSelectProjectChat(project)
            } label: {
                Label("Nouveau chat dans ce projet", systemImage: "bubble.left.and.bubble.right")
            }
            Button(role: .destructive) {
                app.deleteProject(project)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.faint)
            Text("Aucun projet pour l'instant")
                .font(.headline).foregroundStyle(.white)
            Text("Rassemble tes instructions spécifiques et tes documents dans un projet pour personnaliser DarkGPT.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button {
                showingNewProject = true
            } label: {
                Text("Créer mon premier projet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detail / Edit Project
struct ProjectDetailView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State var project: Project
    var onStartChat: (Project) -> Void

    @State private var showingEditSheet = false
    @State private var showingAddFileSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    projectHeader

                    instructionsSection

                    knowledgeFilesSection

                    Spacer(minLength: 20)

                    Button {
                        Haptics.tap()
                        onStartChat(project)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            Text("Démarrer une conversation dans ce projet")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Modifier") { showingEditSheet = true }
                        .foregroundStyle(Theme.accent2)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                ProjectEditorSheet(project: project) { updated in
                    self.project = updated
                    app.upsertProject(updated)
                }
            }
            .sheet(isPresented: $showingAddFileSheet) {
                AddProjectFileSheet { file in
                    var updated = project
                    updated.files.append(file)
                    updated.updated = Date()
                    self.project = updated
                    app.upsertProject(updated)
                }
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(project.color.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: project.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(project.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(project.description.isEmpty ? "Espace de travail personnalisé" : project.description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .cardStyle(radius: 20)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Instructions personnalisées", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            if project.customInstructions.isEmpty {
                Text("Aucune directive spécifique. Modifie le projet pour donner un rôle, ton ou style particulier.")
                    .font(.footnote).foregroundStyle(Theme.faint)
            } else {
                Text(project.customInstructions)
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .cardStyle(radius: 18)
    }

    private var knowledgeFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fichiers de connaissances (\(project.files.count))", systemImage: "doc.on.doc")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showingAddFileSheet = true
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                }
            }

            if project.files.isEmpty {
                Text("Ajoute des snippets de code, docs, directives ou notes pour que l'IA s'en serve comme référence.")
                    .font(.footnote).foregroundStyle(Theme.faint)
            } else {
                ForEach(project.files) { file in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(file.sizeFormatted)
                                .font(.caption2)
                                .foregroundStyle(Theme.faint)
                        }
                        Spacer()
                        Button {
                            var updated = project
                            updated.files.removeAll { $0.id == file.id }
                            self.project = updated
                            app.upsertProject(updated)
                        } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(12)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .cardStyle(radius: 18)
    }
}

// MARK: - Editor Sheet
struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project?
    var onSave: (Project) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColorHex: String = "#E53935"
    @State private var customInstructions: String = ""

    private let availableIcons = [
        "folder.fill", "hammer.fill", "swift", "laptopcomputer", "brain.head.profile",
        "sparkles", "chart.bar.xaxis", "doc.text.fill", "lightbulb.fill", "cube.fill"
    ]
    private let availableColors = [
        "#E53935", "#FF5722", "#4CAF50", "#2196F3", "#9C27B0", "#E91E63", "#00BCD4", "#FFC107"
    ]

    init(project: Project?, onSave: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project?.name ?? "")
        _description = State(initialValue: project?.description ?? "")
        _selectedIcon = State(initialValue: project?.icon ?? "folder.fill")
        _selectedColorHex = State(initialValue: project?.colorHex ?? "#E53935")
        _customInstructions = State(initialValue: project?.customInstructions ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité du projet") {
                    TextField("Nom du projet", text: $name)
                    TextField("Description courte", text: $description)
                }

                Section("Icône & Couleur") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? Theme.surface2 : .clear, in: Circle())
                                        .overlay(Circle().stroke(selectedIcon == icon ? Theme.accent2 : Theme.stroke, lineWidth: 1.5))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableColors, id: \.self) { hex in
                                Button {
                                    selectedColorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .red)
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(.white, lineWidth: selectedColorHex == hex ? 2.5 : 0))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Instructions personnalisées (Prompt système)") {
                    TextEditor(text: $customInstructions)
                        .frame(minHeight: 120)
                        .font(.subheadline)
                    Text("Ces consignes seront automatiquement incluses dans chaque conversation créée dans ce projet.")
                        .font(.caption2).foregroundStyle(Theme.faint)
                }
            }
            .navigationTitle(project == nil ? "Nouveau projet" : "Modifier le projet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var p = project ?? Project(name: name, description: description)
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.description = description.trimmingCharacters(in: .whitespaces)
        p.icon = selectedIcon
        p.colorHex = selectedColorHex
        p.customInstructions = customInstructions
        p.updated = Date()
        onSave(p)
        dismiss()
    }
}

// MARK: - Add File Sheet
struct AddProjectFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (ProjectFile) -> Void

    @State private var fileName = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom du document") {
                    TextField("Ex: Guidelines.md, config.json...", text: $fileName)
                }
                Section("Contenu textuel") {
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            .navigationTitle("Ajouter une connaissance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let f = ProjectFile(name: fileName.trimmingCharacters(in: .whitespaces), content: content)
                        onAdd(f)
                        dismiss()
                    }
                    .disabled(fileName.isEmpty || content.isEmpty)
                }
            }
        }
    }
}
