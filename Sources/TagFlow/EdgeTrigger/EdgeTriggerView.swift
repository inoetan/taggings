import AppKit

/// Visible pocket strip. Supports:
///   - Hover → slide in tag panel
///   - Drag (no file) → reposition to another edge
///   - File drag (NSDraggingDestination) → slide in with URLs
final class EdgeTriggerView: NSView {
    weak var coordinator: DragCoordinator?
    private(set) var edge: ScreenEdge

    /// Called when the user drags the strip to a new edge.
    /// Parameters: new edge, center ratio (0…1) along that edge.
    var onRepositioned: ((ScreenEdge, CGFloat) -> Void)?

    private var dragStartMouse: NSPoint  = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var isRepositioning = false

    // MARK: - Init

    init(edge: ScreenEdge) {
        self.edge = edge
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.edge = .trailing
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        registerForDraggedTypes([.fileURL])
        wantsLayer = true

        // Visual effect background — same material as TagPanelView
        let vfv = NSVisualEffectView()
        vfv.material = .hudWindow
        vfv.blendingMode = .behindWindow
        vfv.state = .active
        vfv.wantsLayer = true
        vfv.layer?.cornerRadius = 6
        vfv.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vfv)
        NSLayoutConstraint.activate([
            vfv.leadingAnchor.constraint(equalTo: leadingAnchor),
            vfv.trailingAnchor.constraint(equalTo: trailingAnchor),
            vfv.topAnchor.constraint(equalTo: topAnchor),
            vfv.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Grip dots
        let grip = GripDotsView(isVertical: edge == .leading || edge == .trailing)
        grip.translatesAutoresizingMaskIntoConstraints = false
        vfv.addSubview(grip)
        NSLayoutConstraint.activate([
            grip.centerXAnchor.constraint(equalTo: vfv.centerXAnchor),
            grip.centerYAnchor.constraint(equalTo: vfv.centerYAnchor),
            grip.widthAnchor.constraint(equalToConstant: 16),
            grip.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    // MARK: - Hover

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
        guard !isRepositioning else { return }
        coordinator?.dragDidEnterEdge(edge, urls: [], stripFrame: window?.frame)
    }

    override func mouseExited(with event: NSEvent) {
        guard !isRepositioning else { return }
        // Don't close if the cursor moved into the tag panel
        let loc = NSEvent.mouseLocation
        if let frame = coordinator?.panelFrame, NSMouseInRect(loc, frame, false) { return }
        coordinator?.dragDidEnd(edge)
    }

    // MARK: - Drag to reposition

    override func mouseDown(with event: NSEvent) {
        dragStartMouse  = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        isRepositioning = false
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = NSEvent.mouseLocation
        let dx = loc.x - dragStartMouse.x
        let dy = loc.y - dragStartMouse.y
        if !isRepositioning && (abs(dx) > 6 || abs(dy) > 6) {
            isRepositioning = true
            coordinator?.dragDidEnd(edge)   // close panel while repositioning
        }
        guard isRepositioning else { return }
        window?.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx,
                                       y: dragStartOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard isRepositioning else { return }
        isRepositioning = false
        snapToNearestEdge()
    }

    private func snapToNearestEdge() {
        guard let win = window else { return }
        let screen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let cx = win.frame.midX, cy = win.frame.midY
        let sf = screen.frame, vf = screen.visibleFrame

        let dLeading  = cx - sf.minX
        let dTrailing = sf.maxX - cx
        let dBottom   = cy - sf.minY
        let dTop      = vf.maxY - cy

        let best = min(dLeading, dTrailing, dBottom, dTop)
        let newEdge: ScreenEdge
        switch best {
        case dLeading:  newEdge = .leading
        case dTrailing: newEdge = .trailing
        case dBottom:   newEdge = .bottom
        default:        newEdge = .top
        }

        let ratio: CGFloat
        switch newEdge {
        case .leading, .trailing:
            ratio = (cy - vf.minY) / max(vf.height, 1)
        case .top, .bottom:
            ratio = (cx - sf.minX) / max(sf.width, 1)
        }
        onRepositioned?(newEdge, max(0.1, min(0.9, ratio)))
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let urls = fileURLs(from: sender), !urls.isEmpty else { return [] }
        coordinator?.dragDidEnterEdge(edge, urls: urls, stripFrame: window?.frame)
        return .link
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard fileURLs(from: sender)?.isEmpty == false else { return [] }
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { coordinator?.dragDidEnd(edge) }
    override func draggingEnded(_ sender: NSDraggingInfo)   { coordinator?.dragDidEnd(edge) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { false }

    private func fileURLs(from info: NSDraggingInfo) -> [URL]? {
        info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
    }
}

// MARK: - Grip indicator

private final class GripDotsView: NSView {
    private let isVertical: Bool
    init(isVertical: Bool) { self.isVertical = isVertical; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.55).setFill()
        let d: CGFloat = 3, gap: CGFloat = 4
        let total = d * 3 + gap * 2
        if isVertical {
            let sx = (bounds.width - d) / 2
            let sy = (bounds.height - total) / 2
            for i in 0..<3 {
                NSBezierPath(ovalIn: CGRect(x: sx, y: sy + CGFloat(i) * (d + gap),
                                            width: d, height: d)).fill()
            }
        } else {
            let sy = (bounds.height - d) / 2
            let sx = (bounds.width - total) / 2
            for i in 0..<3 {
                NSBezierPath(ovalIn: CGRect(x: sx + CGFloat(i) * (d + gap), y: sy,
                                            width: d, height: d)).fill()
            }
        }
    }
}
