import AppKit
import SwiftUI

final class TagBrowserWindowController: NSWindowController {
    private let tagStore: TagStore

    init(tagStore: TagStore) {
        self.tagStore = tagStore

        let view = TagBrowserView(tagStore: tagStore)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "TagFlow — タグブラウザ"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.setFrameAutosaveName("TagBrowserWindow")
        window.minSize = NSSize(width: 500, height: 360)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "TagBrowserToolbar")
        window.toolbar = toolbar

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
