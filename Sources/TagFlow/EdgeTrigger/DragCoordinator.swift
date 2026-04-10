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
        // Fade the strip out while panel is showing
        stripWindow?.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            stripWindow?.animator().alphaValue = 0
        }
        panelController?.slideIn(with: urls, from: stripFrame)
    }

    func dragDidEnd(_ edge: ScreenEdge) {
        panelController?.slideOut { [weak self] in
            self?.stripWindow?.ignoresMouseEvents = false
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
        for url in urls {
            do {
                try XattrService.addTag(tag, to: url)
            } catch {
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
