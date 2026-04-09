import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var edgeTriggerManager: EdgeTriggerManager?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set as early as possible — before SwiftUI creates any window infrastructure
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let tagStore = TagStore.shared
        statusBarController = StatusBarController(tagStore: tagStore)

        edgeTriggerManager = EdgeTriggerManager(tagStore: tagStore)
        edgeTriggerManager?.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        edgeTriggerManager?.teardown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
