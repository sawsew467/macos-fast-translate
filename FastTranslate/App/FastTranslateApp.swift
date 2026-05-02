import SwiftUI

@main
struct FastTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window placeholder — populated in Phase 7
        Settings {
            EmptyView()
        }
    }
}
