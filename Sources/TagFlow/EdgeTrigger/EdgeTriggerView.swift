import AppKit

/// The content view of EdgeTriggerWindow.
/// Implements NSDraggingDestination to receive file drops.
final class EdgeTriggerView: NSView {
    weak var coordinator: DragCoordinator?
    private let edge: ScreenEdge

    init(edge: ScreenEdge) {
        self.edge = edge
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = fileURLs(from: sender), !urls.isEmpty else { return [] }
        coordinator?.dragDidEnterEdge(edge, urls: urls)
        return .link
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = fileURLs(from: sender), !urls.isEmpty else { return [] }
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        coordinator?.dragDidExitEdge(edge)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        coordinator?.dragDidEnd(edge)
    }

    // NSDraggingDestination: we don't handle the drop here — the tag panel does
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
