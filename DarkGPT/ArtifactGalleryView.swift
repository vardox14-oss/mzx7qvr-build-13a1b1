import SwiftUI

struct ArtifactGalleryView: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var selectedFilter: FilterType = .all
    @State private var openedArtifact: Artifact?

    enum FilterType: String, CaseIterable {
        case all = "Tous"
        case interactive = "Apps Web & SVG"
        case code = "Code"
    }

    private var filteredArtifacts: [Artifact] {
        let all = app.allArtifacts
        return all.filter { art in
            let matchQuery = query.isEmpty || art.title.localizedCaseInsensitiveContains(query) || art.content.localizedCaseInsensitiveContains(query)
            guard matchQuery else { return false }
            switch selectedFilter {
            case .all: return true
            case .interactive: return art.isPreviewable
            case .code: return !art.isPreviewable
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                if filteredArtifacts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredArtifacts) { artifact in
                                ArtifactCardView(artifact: artifact) { art in
                                    openedArtifact = art
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Studio d'Artefacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(item: $openedArtifact) { art in
                ArtifactStudioView(artifact: art)
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote)
                    .foregroundStyle(Theme.faint)
                TextField("", text: $query, prompt: Text("Rechercher dans le code et les apps…").foregroundColor(Theme.faint))
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Picker("Filtre", selection: $selectedFilter) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "square.stack.3d.up.badge.automatic")
                .font(.system(size: 44))
                .foregroundStyle(Theme.faint)
            Text("Aucun artefact trouvé")
                .font(.headline).foregroundStyle(.white)
            Text("Demande à DarkGPT de créer une application HTML, un SVG, un script Python ou un composant : il apparaîtra ici sous forme d'artefact interactif.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
            Spacer()
        }
    }
}
