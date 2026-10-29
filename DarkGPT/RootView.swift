import SwiftUI

struct RootView: View {
    var body: some View {
        WebContainerView()
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
    }
}

struct SplashView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            Color(red: 6/255, green: 6/255, blue: 8/255)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.accent.opacity(glow ? 0.6 : 0.2), radius: glow ? 26 : 12)
                    .scaleEffect(glow ? 1.04 : 0.98)

                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
