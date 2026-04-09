import AppKit
import SwiftUI

/// Controls slide-in/out animation for a tag panel anchored to one screen edge.
final class TagPanelWindowController: NSWindowController {
    private let edge: ScreenEdge
    private let screen: NSScreen
    private let tagStore: TagStore
    private weak var coordinator: DragCoordinator?

    private var currentURLs: [URL] = []
    private var isVisible = false

    init(edge: ScreenEdge, screen: NSScreen, tagStore: TagStore, coordinator: DragCoordinator) {
        self.edge = edge
        self.screen = screen
        self.tagStore = tagStore
        self.coordinator = coordinator

        let panelWindow = TagPanelWindow(contentRect: offscreenRect(for: edge, screen: screen))
        super.init(window: panelWindow)
        // Content is set lazily in slideIn to capture the latest URL list
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func slideIn(with urls: [URL]) {
        guard !isVisible else { return }
        currentURLs = urls
        isVisible = true

        guard let coordinator = coordinator else { return }

        // Rebuild SwiftUI content with current URLs
        let view = TagPanelView(
            edge: edge,
            draggedURLs: urls,
            tagStore: tagStore,
            coordinator: coordinator
        )
        let hostingController = NSHostingController(rootView: view)
        hostingController.view.frame = CGRect(origin: .zero, size: panelSize())
        window?.contentViewController = hostingController

        let targetFrame = onscreenRect(for: edge, screen: screen)
        window?.setFrame(offscreenRect(for: edge, screen: screen), display: false)
        window?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().setFrame(targetFrame, display: true)
        }
    }

    func slideOut() {
        guard isVisible else { return }
        isVisible = false

        let targetFrame = offscreenRect(for: edge, screen: screen)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    // MARK: - Frame Calculations

    private func panelSize() -> CGSize {
        let panelWidth = AppSettings.shared.tagPanelWidth
        let screenHeight = screen.visibleFrame.height
        switch edge {
        case .leading, .trailing:
            return CGSize(width: panelWidth, height: min(screenHeight, 500))
        case .top, .bottom:
            return CGSize(width: min(screen.frame.width, 400), height: panelWidth)
        }
    }

    private func onscreenRect(for edge: ScreenEdge, screen: NSScreen) -> CGRect {
        let size = panelSize()
        let sf = screen.frame
        let vf = screen.visibleFrame
        switch edge {
        case .leading:
            return CGRect(x: sf.minX, y: vf.midY - size.height / 2, width: size.width, height: size.height)
        case .trailing:
            return CGRect(x: sf.maxX - size.width, y: vf.midY - size.height / 2, width: size.width, height: size.height)
        case .top:
            return CGRect(x: sf.midX - size.width / 2, y: vf.maxY - size.height, width: size.width, height: size.height)
        case .bottom:
            return CGRect(x: sf.midX - size.width / 2, y: sf.minY, width: size.width, height: size.height)
        }
    }

    private func offscreenRect(for edge: ScreenEdge, screen: NSScreen) -> CGRect {
        var rect = onscreenRect(for: edge, screen: screen)
        switch edge {
        case .leading:   rect.origin.x -= rect.width
        case .trailing:  rect.origin.x += rect.width
        case .top:       rect.origin.y += rect.height
        case .bottom:    rect.origin.y -= rect.height
        }
        return rect
    }
}
