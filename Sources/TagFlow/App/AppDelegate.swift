import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var edgeTriggerManager: EdgeTriggerManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory (no Dock icon, doesn't steal focus)
        NSApp.setActivationPolicy(.accessory)

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
