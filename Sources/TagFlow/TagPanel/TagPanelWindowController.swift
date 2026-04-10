import AppKit
import SwiftUI

/// Controls the tag panel window. Animates by expanding from the pocket strip frame.
final class TagPanelWindowController: NSWindowController {
    private let edge: ScreenEdge
    private let screen: NSScreen
    private let tagStore: TagStore
    private weak var coordinator: DragCoordinator?

    private var isVisible = false

    init(edge: ScreenEdge, screen: NSScreen, tagStore: TagStore, coordinator: DragCoordinator) {
        self.edge = edge
        self.screen = screen
        self.tagStore = tagStore
        self.coordinator = coordinator

        let panelWindow = TagPanelWindow(contentRect: .zero)
        panelWindow.isRestorable = false
        super.init(window: panelWindow)
    }

    required init?(coder: NSCoder) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        self.edge = .trailing
        self.screen = screen
        self.tagStore = TagStore.shared
        self.isVisible = false
        super.init(coder: coder)
    }

    // MARK: - Public

    /// Slide in the panel, expanding from `stripFrame` if provided.
    func slideIn(with urls: [URL], from stripFrame: NSRect? = nil) {
        if isVisible {
            // Panel already open — update URLs if a real file drag arrives
            if !urls.isEmpty { updateContent(urls: urls) }
            return
        }
        isVisible = true
        guard let coordinator = coordinator else { return }

        let stripCenter = stripFrame.map { NSPoint(x: $0.midX, y: $0.midY) }
        let targetFrame = Self.onscreenRect(for: edge, screen: screen, near: stripCenter)

        let view = TagPanelView(edge: edge, draggedURLs: urls,
                                tagStore: tagStore, coordinator: coordinator)
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = CGRect(origin: .zero, size: targetFrame.size)
        window?.contentViewController = hosting

        // Start from strip frame and expand — "にゅっと拡大" effect
        let startFrame = stripFrame ?? targetFrame
        window?.alphaValue = 0
        window?.setFrame(startFrame, display: false)
        window?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().setFrame(targetFrame, display: true)
            window?.animator().alphaValue = 1
        }
    }

    func slideOut(completion: (() -> Void)? = nil) {
        guard isVisible else { completion?(); return }
        isVisible = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            completion?()
        }
    }

    // MARK: - Private

    private func updateContent(urls: [URL]) {
        guard let coordinator = coordinator else { return }
        let view = TagPanelView(edge: edge, draggedURLs: urls,
                                tagStore: tagStore, coordinator: coordinator)
        window?.contentViewController = NSHostingController(rootView: view)
    }

    // MARK: - Frame helpers

    /// Panel rect anchored to the edge, centered near the strip's position.
    static func onscreenRect(for edge: ScreenEdge, screen: NSScreen,
                              near stripCenter: NSPoint? = nil) -> CGRect {
        let size = panelSize(edge: edge, screen: screen)
        let sf = screen.frame
        let vf = screen.visibleFrame

        switch edge {
        case .trailing:
            let cy = (stripCenter?.y ?? vf.midY)
                .clamped(to: vf.minY + size.height / 2 ... vf.maxY - size.height / 2)
            return CGRect(x: sf.maxX - size.width, y: cy - size.height / 2,
                          width: size.width, height: size.height)
        case .leading:
            let cy = (stripCenter?.y ?? vf.midY)
                .clamped(to: vf.minY + size.height / 2 ... vf.maxY - size.height / 2)
            return CGRect(x: sf.minX, y: cy - size.height / 2,
                          width: size.width, height: size.height)
        case .top:
            let cx = (stripCenter?.x ?? sf.midX)
                .clamped(to: sf.minX + size.width / 2 ... sf.maxX - size.width / 2)
            return CGRect(x: cx - size.width / 2, y: vf.maxY - size.height,
                          width: size.width, height: size.height)
        case .bottom:
            let cx = (stripCenter?.x ?? sf.midX)
                .clamped(to: sf.minX + size.width / 2 ... sf.maxX - size.width / 2)
            return CGRect(x: cx - size.width / 2, y: sf.minY,
                          width: size.width, height: size.height)
        }
    }

    static func panelSize(edge: ScreenEdge, screen: NSScreen) -> CGSize {
        let w = AppSettings.shared.tagPanelWidth
        switch edge {
        case .leading, .trailing:
            return CGSize(width: w, height: min(screen.visibleFrame.height, 500))
        case .top, .bottom:
            return CGSize(width: min(screen.frame.width, 400), height: w)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
