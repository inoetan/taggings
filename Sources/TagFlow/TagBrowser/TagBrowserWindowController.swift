import AppKit
import SwiftUI

final class TagBrowserWindowController: NSWindowController {
    private let navigation: TagBrowserNavigation

    init(tagStore: TagStore, initialTag: Tag? = nil) {
        let nav = TagBrowserNavigation()
        nav.selectedTag = initialTag
        self.navigation = nav

        let view = TagBrowserView(tagStore: tagStore, navigation: nav)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "TagFlow — タグブラウザ"
        window.setContentSize(NSSize(width: 760, height: 520))
        window.setFrameAutosaveName("TagBrowserWindow")
        window.minSize = NSSize(width: 540, height: 380)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isRestorable = false
        let toolbar = NSToolbar(identifier: "TagBrowserToolbar")
        window.toolbar = toolbar

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        self.navigation = TagBrowserNavigation()
        super.init(coder: coder)
    }

    /// Navigate to a specific tag without recreating the window.
    /// Called by the status bar when the user clicks a tag menu item.
    func navigate(to tag: Tag) {
        navigation.selectedTag = tag
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
