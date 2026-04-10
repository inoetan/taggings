import AppKit

/// The content view of EdgeTriggerWindow.
/// Shows a visible strip for debugging. Slides in the tag panel on mouse hover.
final class EdgeTriggerView: NSView {
    weak var coordinator: DragCoordinator?
    private let edge: ScreenEdge

    init(edge: ScreenEdge) {
        self.edge = edge
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        self.edge = .leading
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    // MARK: - Drawing (debug: visible strip)

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.45).setFill()
        bounds.fill()

        // Draw a left-pointing arrow to indicate "drag here"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let symbol = "◀"
        let size = (symbol as NSString).size(withAttributes: attrs)
        let x = (bounds.width - size.width) / 2
        let y = (bounds.height - size.height) / 2
        (symbol as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    // MARK: - Hover (mouse-over slide in for debug)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        print("[EdgeTrigger] mouseEntered edge=\(edge)")
        coordinator?.dragDidEnterEdge(edge, urls: [])
    }

    override func mouseExited(with event: NSEvent) {
        print("[EdgeTrigger] mouseExited edge=\(edge)")
        coordinator?.dragDidEnd(edge)
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("[EdgeTrigger] draggingEntered edge=\(edge)")
        guard let urls = fileURLs(from: sender), !urls.isEmpty else { return [] }
        coordinator?.dragDidEnterEdge(edge, urls: urls)
        return .link
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = fileURLs(from: sender), !urls.isEmpty else { return [] }
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        coordinator?.dragDidEnd(edge)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        coordinator?.dragDidEnd(edge)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return false
    }

    // MARK: - Helpers

    private func fileURLs(from info: NSDraggingInfo) -> [URL]? {
        info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true
        ]) as? [URL]
    }
}
