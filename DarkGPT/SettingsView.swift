import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        profileCard
                        creditsCard
                        linksCard
                        Button(role: .destructive) { confirmLogout = true } label: {
                            Text("Se déconnecter").frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
                                .foregroundStyle(Theme.accent2)
                        }
                        Text("DarkGPT iOS · v1.0").font(.caption2).foregroundStyle(Theme.faint)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
            .confirmationDialog("Se déconnecter ?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Se déconnecter", role: .destructive) { Task { await app.logout(); dismiss() } }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            AsyncImage(url: app.user?.avatar) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image("Logo").resizable().scaledToFit().padding(6)
            }
            .frame(width: 56, height: 56).background(Theme.surface2).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(app.user?.name ?? "Utilisateur").font(.headline).foregroundStyle(.white)
                Text(app.user?.email ?? "").font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                Text(app.user?.planLabel ?? "Gratuit").font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.9), in: Capsule()).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(16).cardStyle()
    }

    private var creditsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Gems disponibles", systemImage: "diamond.fill").font(.subheadline).foregroundStyle(Theme.muted)
                Spacer()
                Text(formatGems(app.user?.gems ?? 0)).font(.title3.weight(.bold)).foregroundStyle(.white)
            }
            Link(destination: URL(string: "https://darkgptshop.mysellauth.com")!) {
                Text("Recharger des gems").frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white).fontWeight(.semibold)
            }
        }
        .padding(16).cardStyle()
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            linkRow("Tous les modèles", "square.grid.2x2", "https://darkgpt.chat/modeles")
            Divider().overlay(Theme.stroke)
            linkRow("Centre d'aide", "lifepreserver", "https://darkgpt.chat/support")
            Divider().overlay(Theme.stroke)
            linkRow("Conditions d'utilisation", "doc.text", "https://darkgpt.chat/cgu")
        }
        .padding(.horizontal, 16).cardStyle()
    }

    private func linkRow(_ title: String, _ icon: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(.white).font(.subheadline)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Theme.faint)
            }
            .padding(.vertical, 14)
        }
    }
}
