import SwiftUI

@main
struct TagFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — the app lives in the menu bar.
        // Settings scene keeps the app from presenting a default window.
        Settings {
            EmptyView()
        }
    }
}
