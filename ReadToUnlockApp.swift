import SwiftUI

@main
struct ReadToUnlockApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var readingManager = ReadingManager()
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(readingManager)
                .environmentObject(screenTimeManager)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        appState.rotateFeaturedSeed()
                    }
                }
        }
    }
}
