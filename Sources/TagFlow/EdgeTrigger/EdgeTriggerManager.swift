import AppKit

/// Creates and manages edge trigger windows and tag panel windows for all screens.
/// EdgeTriggerWindows are always active (ignoresMouseEvents = false) so they can
/// receive NSDragging events directly — no global event monitor is needed.
final class EdgeTriggerManager {
    private let tagStore: TagStore
    private let coordinator: DragCoordinator

    private var edgeWindows: [ScreenEdge: EdgeTriggerWindow] = [:]
    private var panelControllers: [ScreenEdge: TagPanelWindowController] = [:]

    // Fallback: close any open panel when the mouse button is released,
    // in case draggingEnded on EdgeTriggerView is not called (e.g. drop on panel).
    private var mouseUpMonitor: Any?

    init(tagStore: TagStore) {
        self.tagStore = tagStore
        self.coordinator = DragCoordinator(tagStore: tagStore)
    }

    func setup() {
        buildWindowsForMainScreen()
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
        edgeWindows.values.forEach { $0.orderOut(nil) }
        panelControllers.values.forEach { $0.window?.orderOut(nil) }
        edgeWindows.removeAll()
        panelControllers.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Window Construction

    private func buildWindowsForMainScreen() {
        guard let screen = NSScreen.main else { return }
        buildWindows(for: screen)
    }

    private func buildWindows(for screen: NSScreen) {
        // DEBUG: limit to trailing edge only for initial testing
        let activeEdges: [ScreenEdge] = [.trailing]
        for edge in activeEdges {
            let edgeWin = EdgeTriggerWindow(edge: edge, screen: screen)
            let edgeView = EdgeTriggerView(edge: edge)
            edgeView.coordinator = coordinator
            edgeWin.contentView = edgeView
            edgeWin.orderFrontRegardless()
            edgeWindows[edge] = edgeWin

            let panelCtrl = TagPanelWindowController(edge: edge, screen: screen, tagStore: tagStore, coordinator: coordinator)
            coordinator.registerPanelController(panelCtrl, for: edge)
            panelControllers[edge] = panelCtrl
        }
    }

    @objc private func screensDidChange() {
        teardownWindows()
        buildWindowsForMainScreen()
    }

    private func teardownWindows() {
        edgeWindows.values.forEach { $0.orderOut(nil) }
        panelControllers.values.forEach { $0.window?.orderOut(nil) }
        edgeWindows.removeAll()
        panelControllers.removeAll()
    }

    // MARK: - Mouse-Up Monitor

    private func startMouseUpMonitor() {
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.slideOutAllPanels()
        }
    }

    private func stopMouseUpMonitor() {
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
    }

    private func slideOutAllPanels() {
        panelControllers.values.forEach { $0.slideOut() }
    }
}
