import AppKit

/// Creates and manages edge trigger windows and tag panel windows for all screens.
/// Uses a global NSEvent monitor to detect when a drag approaches a screen edge,
/// then enables mouse event handling on the corresponding edge window.
final class EdgeTriggerManager {
    private let tagStore: TagStore
    private let coordinator: DragCoordinator

    // screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] -> [ScreenEdge: ...]
    private var edgeWindows: [ScreenEdge: EdgeTriggerWindow] = [:]
    private var panelControllers: [ScreenEdge: TagPanelWindowController] = [:]

    private var dragMonitor: Any?
    private var mouseUpMonitor: Any?

    init(tagStore: TagStore) {
        self.tagStore = tagStore
        self.coordinator = DragCoordinator(tagStore: tagStore)
    }

    func setup() {
        buildWindowsForMainScreen()
        startGlobalMonitors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func teardown() {
        stopGlobalMonitors()
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
        for edge in ScreenEdge.allCases {
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

    // MARK: - Global Event Monitoring

    private func startGlobalMonitors() {
        // Fires when a drag (left mouse button held + moved) occurs in another app
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleGlobalDrag(at: NSEvent.mouseLocation)
        }
        // On mouse-up: disable hot zones and close any open panel.
        // This handles cancellations that happen while the drag is over the tag panel
        // (where draggingEnded on EdgeTriggerView is NOT called).
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.disableAllEdgeWindows()
            self?.slideOutAllPanels()
        }
    }

    private func stopGlobalMonitors() {
        if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
    }

    /// Enables the edge window when the drag pointer enters the hot zone (20px from edge).
    private func handleGlobalDrag(at location: CGPoint) {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }) else {
            disableAllEdgeWindows()
            return
        }
        let hotZone = AppSettings.shared.edgeHotZoneWidth
        let sf = screen.frame

        var nearEdge: ScreenEdge? = nil
        if location.x - sf.minX < hotZone  { nearEdge = .leading }
        if sf.maxX - location.x < hotZone  { nearEdge = .trailing }
        if location.y - sf.minY < hotZone  { nearEdge = .bottom }
        if sf.maxY - location.y < hotZone  { nearEdge = .top }

        for edge in ScreenEdge.allCases {
            edgeWindows[edge]?.ignoresMouseEvents = (edge != nearEdge)
        }
    }

    private func disableAllEdgeWindows() {
        edgeWindows.values.forEach { $0.ignoresMouseEvents = true }
    }

    private func slideOutAllPanels() {
        panelControllers.values.forEach { $0.slideOut() }
    }
}
