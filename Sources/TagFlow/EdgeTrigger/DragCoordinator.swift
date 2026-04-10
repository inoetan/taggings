import AppKit

/// Routes drag/hover events from the pocket strip to the tag panel and XattrService.
final class DragCoordinator {
    private var panelController: TagPanelWindowController?
    private var currentEdge: ScreenEdge?
    private let tagStore: TagStore

    /// The pocket strip window — faded out while the panel is open.
    weak var stripWindow: NSWindow?

    /// Current panel window frame — used by EdgeTriggerView to avoid closing when
    /// the cursor moves from the strip into the panel.
    var panelFrame: NSRect? { panelController?.window?.frame }

    init(tagStore: TagStore) {
        self.tagStore = tagStore
    }

    func registerPanelController(_ controller: TagPanelWindowController, for edge: ScreenEdge) {
        panelController = controller
        currentEdge = edge
    }

    func clearPanelController() {
        panelController?.window?.orderOut(nil)
        panelController = nil
        currentEdge = nil
    }

    // MARK: - Events from EdgeTriggerView

    func dragDidEnterEdge(_ edge: ScreenEdge, urls: [URL], stripFrame: NSRect? = nil) {
        print("[Coordinator] dragDidEnterEdge edge=\(edge) urls=\(urls.count)")
        // Defer UI work to the next run loop to avoid re-entrancy in the
        // drag IPC callback (kDragIPCLeaveApplication / kDragIPCCompleted).
        let strip = stripWindow
        let panel = panelController
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                strip?.animator().alphaValue = 0
            }
            panel?.slideIn(with: urls, from: stripFrame)
        }
    }

    func dragDidEnd(_ edge: ScreenEdge) {
        panelController?.slideOut { [weak self] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self?.stripWindow?.animator().alphaValue = 1
            }
        }
    }

    func slideOutAll() {
        guard let edge = currentEdge else { return }
        dragDidEnd(edge)
    }

    // MARK: - Tag application (called by TagPanelView)

    func applyTag(_ tag: Tag, to urls: [URL]) {
        print("[Coordinator] applyTag tag=\(tag.name) files=\(urls.count)")
        for url in urls {
            do {
                try XattrService.addTag(tag, to: url)
                print("[Coordinator] tagged \(url.lastPathComponent) with \(tag.name)")
            } catch {
                print("[Coordinator] error: \(error)")
                presentError(error)
            }
        }
    }

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
