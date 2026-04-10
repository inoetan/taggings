import AppKit

/// Manages the single repositionable pocket strip and its associated tag panel.
final class EdgeTriggerManager {
    private let tagStore: TagStore
    private let coordinator: DragCoordinator

    private var pocketWindow: EdgeTriggerWindow?
    private var pocketEdge: ScreenEdge = .trailing
    private var pocketCenterRatio: CGFloat = 0.5

    private var mouseUpMonitor: Any?

    init(tagStore: TagStore) {
        self.tagStore = tagStore
        self.coordinator = DragCoordinator(tagStore: tagStore)
    }

    func setup() {
        buildPocket()
        startMouseUpMonitor()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func teardown() {
        stopMouseUpMonitor()
        pocketWindow?.orderOut(nil)
        coordinator.clearPanelController()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Build

    private func buildPocket() {
        guard let screen = NSScreen.main else { return }

        pocketWindow?.orderOut(nil)
        coordinator.clearPanelController()

        let win = EdgeTriggerWindow(edge: pocketEdge, screen: screen,
                                    centerRatio: pocketCenterRatio)
        let view = EdgeTriggerView(edge: pocketEdge)
        view.coordinator = coordinator
        view.onRepositioned = { [weak self] newEdge, ratio in
            self?.pocketEdge = newEdge
            self?.pocketCenterRatio = ratio
            self?.buildPocket()
        }
        win.contentView = view
        win.orderFrontRegardless()
        pocketWindow = win
        coordinator.stripWindow = win

        let panel = TagPanelWindowController(
            edge: pocketEdge, screen: screen,
            tagStore: tagStore, coordinator: coordinator
        )
        coordinator.registerPanelController(panel, for: pocketEdge)
    }

    @objc private func screensDidChange() { buildPocket() }

    // MARK: - Mouse-up fallback

    private func startMouseUpMonitor() {
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.coordinator.slideOutAll()
        }
    }

    private func stopMouseUpMonitor() {
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
    }
}
