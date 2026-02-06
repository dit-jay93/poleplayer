import SwiftUI

@main
struct PolePlayerApp: App {
    @StateObject private var appState = AppState()

    init() {
        FontRegistrar.registerAll()
        CrashLogger.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.font, AppFont.body)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open…") {
                    appState.openPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
