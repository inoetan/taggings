import AppKit
import SwiftUI

/// Controls slide-in/out animation for a tag panel anchored to one screen edge.
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

        // Use static helper — instance methods cannot be called before super.init
        let initFrame = Self.offscreenRect(for: edge, screen: screen)
        let panelWindow = TagPanelWindow(contentRect: initFrame)
        super.init(window: panelWindow)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func slideIn(with urls: [URL]) {
        guard !isVisible else { return }
        isVisible = true

        guard let coordinator = coordinator else { return }

        let view = TagPanelView(
            edge: edge,
            draggedURLs: urls,
            tagStore: tagStore,
            coordinator: coordinator
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = CGRect(origin: .zero, size: Self.panelSize(edge: edge, screen: screen))
        window?.contentViewController = hosting

        let targetFrame = Self.onscreenRect(for: edge, screen: screen)
        window?.setFrame(Self.offscreenRect(for: edge, screen: screen), display: false)
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

        let targetFrame = Self.offscreenRect(for: edge, screen: screen)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window?.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    // MARK: - Frame Calculations (static to avoid pre-super.init restrictions)

    static func panelSize(edge: ScreenEdge, screen: NSScreen) -> CGSize {
        let panelWidth = AppSettings.shared.tagPanelWidth
        switch edge {
        case .leading, .trailing:
            return CGSize(width: panelWidth, height: min(screen.visibleFrame.height, 500))
        case .top, .bottom:
            return CGSize(width: min(screen.frame.width, 400), height: panelWidth)
        }
    }

    static func onscreenRect(for edge: ScreenEdge, screen: NSScreen) -> CGRect {
        let size = panelSize(edge: edge, screen: screen)
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

    static func offscreenRect(for edge: ScreenEdge, screen: NSScreen) -> CGRect {
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
