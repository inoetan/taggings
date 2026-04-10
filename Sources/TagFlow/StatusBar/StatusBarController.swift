import AppKit
import Combine

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let tagStore: TagStore
    private var tagBrowserWindowController: TagBrowserWindowController?
    private var cancellables = Set<AnyCancellable>()

    init(tagStore: TagStore) {
        self.tagStore = tagStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tag", accessibilityDescription: "TagFlow")
            button.imageScaling = .scaleProportionallyDown
        }
        buildMenu()
        tagStore.$tags
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.buildMenu() }
            .store(in: &cancellables)
    }

    private func buildMenu() {
        let menu = NSMenu()

        let browserItem = NSMenuItem(
            title: "タグブラウザを開く",
            action: #selector(openTagBrowser),
            keyEquivalent: "t"
        )
        browserItem.target = self
        menu.addItem(browserItem)

        menu.addItem(.separator())

        if tagStore.tags.isEmpty {
            let empty = NSMenuItem(title: "タグがありません", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for tag in tagStore.tags {
                let item = NSMenuItem(
                    title: tag.name,
                    action: #selector(openTagBrowserToTag(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                // Store the tag name as a String (bridges to NSString for representedObject).
                // On click we look it up in tagStore to get the current Tag value.
                item.representedObject = tag.name
                item.image = colorDot(tag.color.nsColor)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "TagFlowを終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func openTagBrowser() {
        ensureBrowserOpen()
    }

    @objc private func openTagBrowserToTag(_ sender: NSMenuItem) {
        ensureBrowserOpen()
        if let name = sender.representedObject as? String,
           let tag = tagStore.tag(named: name) {
            tagBrowserWindowController?.navigate(to: tag)
        }
    }

    private func ensureBrowserOpen() {
        if tagBrowserWindowController == nil {
            tagBrowserWindowController = TagBrowserWindowController(tagStore: tagStore)
        }
        tagBrowserWindowController?.showWindow(nil)
        tagBrowserWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func colorDot(_ color: NSColor) -> NSImage {
        let size = CGSize(width: 12, height: 12)
        return NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }
}
