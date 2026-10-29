import SwiftUI

struct AutomationsView: View {
    @EnvironmentObject var app: AppState
    var onRunTask: (ScheduledTask) -> Void

    @State private var showingNewTaskSheet = false
    @State private var editingTask: ScheduledTask?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    banner

                    if app.tasks.isEmpty {
                        emptyView
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(app.tasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Tâches & Automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showingNewTaskSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showingNewTaskSheet) {
                TaskEditorSheet(task: nil) { newTask in
                    app.upsertTask(newTask)
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(task: task) { updated in
                    app.upsertTask(updated)
                }
            }
            .task {
                _ = await NotificationManager.shared.requestAuthorization()
            }
        }
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.badge.clock")
                    .font(.title3)
                    .foregroundStyle(Theme.accent2)
                Text("Prompts programmés & Rappels")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text("Automatise tes routines : veille matinale, compte-rendu, révision d'objectifs. Reçois des rappels et exécute en 1 tap.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .cardStyle(radius: 18)
    }

    private func taskRow(_ task: ScheduledTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(task.isEnabled ? Theme.accent.opacity(0.2) : Theme.surface2)
                        .frame(width: 44, height: 44)
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(task.isEnabled ? Theme.accent2 : Theme.faint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(task.scheduleSummary)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { task.isEnabled },
                    set: { enabled in
                        var updated = task
                        updated.isEnabled = enabled
                        app.upsertTask(updated)
                    }
                ))
                .labelsHidden()
                .tint(Theme.accent)
            }

            Text(task.prompt)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.8))
                .lineLimit(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack {
                Button {
                    Haptics.tap()
                    editingTask = task
                } label: {
                    Text("Modifier")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                Button {
                    Haptics.success()
                    onRunTask(task)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Lancer maintenant")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .cardStyle(radius: 18)
        .contextMenu {
            Button(role: .destructive) {
                app.deleteTask(task)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "alarm")
                .font(.system(size: 40))
                .foregroundStyle(Theme.faint)
            Text("Aucune tâche programmée")
                .font(.headline).foregroundStyle(.white)
            Text("Configure un prompt récurrent (ex: résumé de la journée, veille tech) pour ne plus avoir à le taper à la main.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button {
                showingNewTaskSheet = true
            } label: {
                Text("Programmer une tâche")
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

// MARK: - Task Editor Sheet
struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let task: ScheduledTask?
    var onSave: (ScheduledTask) -> Void

    @State private var title: String = ""
    @State private var prompt: String = ""
    @State private var frequency: TaskFrequency = .daily
    @State private var selectedDate = Date()
    @State private var dayOfWeek: Int = 2

    init(task: ScheduledTask?, onSave: @escaping (ScheduledTask) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _prompt = State(initialValue: task?.prompt ?? "")
        _frequency = State(initialValue: task?.frequency ?? .daily)
        _dayOfWeek = State(initialValue: task?.dayOfWeek ?? 2)

        var comps = DateComponents()
        comps.hour = task?.hour ?? 9
        comps.minute = task?.minute ?? 0
        let date = Calendar.current.date(from: comps) ?? Date()
        _selectedDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tâche") {
                    TextField("Titre (ex: Veille matinale)", text: $title)
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                        .font(.subheadline)
                }

                Section("Fréquence & Heure") {
                    Picker("Fréquence", selection: $frequency) {
                        ForEach(TaskFrequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }

                    if frequency == .weekly {
                        Picker("Jour", selection: $dayOfWeek) {
                            Text("Lundi").tag(2)
                            Text("Mardi").tag(3)
                            Text("Mercredi").tag(4)
                            Text("Jeudi").tag(5)
                            Text("Vendredi").tag(6)
                            Text("Samedi").tag(7)
                            Text("Dimanche").tag(1)
                        }
                    }

                    DatePicker("Heure d'exécution", selection: $selectedDate, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle(task == nil ? "Nouvelle tâche" : "Modifier la tâche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var t = task ?? ScheduledTask(title: title, prompt: prompt)
        t.title = title.trimmingCharacters(in: .whitespaces)
        t.prompt = prompt.trimmingCharacters(in: .whitespaces)
        t.frequency = frequency
        t.dayOfWeek = dayOfWeek

        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
        t.hour = comps.hour ?? 9
        t.minute = comps.minute ?? 0
        t.isEnabled = true

        onSave(t)
        NotificationManager.shared.scheduleTask(t)
        dismiss()
    }
}
