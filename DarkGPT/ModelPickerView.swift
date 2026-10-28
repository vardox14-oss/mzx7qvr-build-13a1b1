import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject var app: AppState
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var grouped: [(category: String, sort: Int, models: [AIModel])] {
        let models = app.chatModels.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        let groups = Dictionary(grouping: models) { $0.category }
        return groups.map { (key, value) in
            (key, value.first?.categorySort ?? 999, value.sorted { $0.sortOrder < $1.sortOrder })
        }.sorted { $0.sort < $1.sort }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(grouped, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.category.uppercased())
                                    .font(.caption.weight(.bold)).foregroundStyle(Theme.faint)
                                ForEach(group.models) { model in
                                    row(model)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Choisir un modèle")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Rechercher un modèle")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
        }
    }

    private func row(_ model: AIModel) -> some View {
        let unlocked = model.isUnlocked(for: app.plan)
        return Button {
            guard unlocked else { Haptics.error(); return }
            Haptics.tap(); selected = model.slug; dismiss()
        } label: {
            HStack(spacing: 12) {
                logo(model)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                        if model.hasThinkingToggle {
                            Image(systemName: "brain").font(.caption2).foregroundStyle(Theme.accent2)
                        }
                    }
                    if !model.summary.isEmpty {
                        Text(model.summary).font(.caption2).foregroundStyle(Theme.muted).lineLimit(2)
                    }
                }
                Spacer()
                if !unlocked {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.caption2)
                        Text(Plans.label(model.minPlan)).font(.caption2.weight(.semibold))
                    }.foregroundStyle(Theme.faint)
                } else if model.gemCost > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "diamond.fill").font(.caption2)
                        Text("\(model.gemCost)").font(.caption2.weight(.semibold))
                    }.foregroundStyle(Theme.accent2)
                }
                if model.slug == selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
            }
            .padding(12)
            .cardStyle(radius: 14)
            .opacity(unlocked ? 1 : 0.55)
        }
    }

    @ViewBuilder private func logo(_ model: AIModel) -> some View {
        if let url = model.logo {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "sparkles").foregroundStyle(Theme.muted)
            }
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Theme.surface2).frame(width: 30, height: 30)
                .overlay(Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.muted))
        }
    }
}
