import AppKit

/// A short pocket strip anchored to a screen edge. The user can drag it to any edge.
final class EdgeTriggerWindow: NSWindow {
    let edge: ScreenEdge
    let targetScreen: NSScreen

    /// Thickness of the VISIBLE strip (perpendicular to edge).
    static let visualThickness: CGFloat = 16
    /// Thickness of the ACTIVATION ZONE (window size perpendicular to edge).
    /// Larger than the visual strip so dragging files is much easier to hit.
    static let hitThickness: CGFloat = 48
    /// Length of the pocket along the edge.
    static let length: CGFloat = 200

    init(edge: ScreenEdge, screen: NSScreen, centerRatio: CGFloat = 0.5) {
        self.edge = edge
        self.targetScreen = screen
        let frame = EdgeTriggerWindow.pocketRect(for: edge, screen: screen, centerRatio: centerRatio)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered,
                   defer: false, screen: screen)
        configure()
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        self.edge = .trailing
        self.targetScreen = NSScreen.main ?? NSScreen.screens[0]
        super.init(contentRect: contentRect, styleMask: style,
                   backing: backingStoreType, defer: flag)
    }

    required init?(coder: NSCoder) {
        self.edge = .trailing
        self.targetScreen = NSScreen.main ?? NSScreen.screens[0]
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        isRestorable = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // NOTE: .screenSaver level (~2000) causes macOS to skip this window when routing
        // NSDragging IPC — draggingEntered never fires at that level.
        // .floating ensures both NSTrackingArea and NSDragging are delivered normally.
        level = .floating
    }

    /// The pocket rect: window extends `hitThickness` inward from the edge,
    /// centered at `centerRatio` (0…1) along the edge.
    static func pocketRect(for edge: ScreenEdge, screen: NSScreen, centerRatio: CGFloat = 0.5) -> CGRect {
        let sf = screen.frame
        let vf = screen.visibleFrame
        let h = hitThickness, l = length

        switch edge {
        case .trailing:
            let cy = vf.minY + vf.height * centerRatio
            return CGRect(x: sf.maxX - h, y: cy - l / 2, width: h, height: l)
        case .leading:
            let cy = vf.minY + vf.height * centerRatio
            return CGRect(x: sf.minX, y: cy - l / 2, width: h, height: l)
        case .top:
            let cx = sf.minX + sf.width * centerRatio
            return CGRect(x: cx - l / 2, y: vf.maxY - h, width: l, height: h)
        case .bottom:
            let cx = sf.minX + sf.width * centerRatio
            return CGRect(x: cx - l / 2, y: sf.minY, width: l, height: h)
        }
    }
}
