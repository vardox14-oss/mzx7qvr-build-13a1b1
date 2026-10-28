import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch app.phase {
            case .loading:
                SplashView()
            case .loggedOut:
                LoginView()
                    .transition(.opacity)
            case .loggedIn:
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.phase)
    }
}

struct SplashView: View {
    @State private var glow = false
    var body: some View {
        VStack(spacing: 18) {
            Image("Logo").resizable().scaledToFit().frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Theme.accent.opacity(glow ? 0.5 : 0.2), radius: glow ? 26 : 12)
                .scaleEffect(glow ? 1.04 : 0.98)
            ProgressView().tint(Theme.muted)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { glow = true } }
    }
}
