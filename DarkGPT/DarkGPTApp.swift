import SwiftUI

@main
struct DarkGPTApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { await app.bootstrap() }
        }
    }
}
