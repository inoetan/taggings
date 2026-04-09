import AppKit

/// Routes drag events from edge trigger windows to tag panels and the XattrService.
final class DragCoordinator {
    // Keyed by (screen, edge)
    private var tagPanelControllers: [ScreenEdge: TagPanelWindowController] = [:]
    private var currentSession: DragSession?
    private let tagStore: TagStore

    init(tagStore: TagStore) {
        self.tagStore = tagStore
    }

    func registerPanelController(_ controller: TagPanelWindowController, for edge: ScreenEdge) {
        tagPanelControllers[edge] = controller
    }

    // MARK: - Events from EdgeTriggerView

    func dragDidEnterEdge(_ edge: ScreenEdge, urls: [URL]) {
        let session = DragSession(urls: urls, sourceEdge: edge)
        currentSession = session
        tagPanelControllers[edge]?.slideIn(with: urls)
    }

    func dragDidExitEdge(_ edge: ScreenEdge) {
        // Don't immediately hide — the drag may have moved into the tag panel itself
        // The panel controller handles hiding when drag exits the panel
    }

    func dragDidEnd(_ edge: ScreenEdge) {
        tagPanelControllers[edge]?.slideOut()
        currentSession = nil
    }

    // Called by TagPanelView when the user drops files onto a tag
    func applyTag(_ tag: Tag, to urls: [URL]) {
        for url in urls {
            do {
                try XattrService.addTag(tag, to: url)
            } catch {
                presentError(error)
            }
        }
    }

    // MARK: - Private

    private func presentError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "タグの書き込みに失敗しました"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
