import AppKit

/// An invisible, always-on-top strip window parked at a screen edge.
/// Normally click-through; becomes interactive when a drag approaches the edge.
final class EdgeTriggerWindow: NSWindow {
    let edge: ScreenEdge
    let targetScreen: NSScreen  // renamed: NSWindow already has `var screen: NSScreen?`

    init(edge: ScreenEdge, screen: NSScreen) {
        self.edge = edge
        self.targetScreen = screen
        let frame = EdgeTriggerWindow.edgeRect(for: edge, screen: screen)
        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        configure()
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        isRestorable = false  // never restore edge trigger windows across sessions
        // Must appear on all spaces including fullscreen apps
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // Above all normal windows; .screenSaver ensures visibility over fullscreen apps
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
    }

    /// The hot-zone rect for an edge — a thin strip spanning the full edge.
    static func edgeRect(for edge: ScreenEdge, screen: NSScreen) -> CGRect {
        let sf = screen.frame
        let vf = screen.visibleFrame
        let hotZone = AppSettings.shared.edgeHotZoneWidth

        switch edge {
        case .top:
            // Use visibleFrame top to avoid menu bar on the main screen
            return CGRect(x: sf.minX, y: vf.maxY - hotZone, width: sf.width, height: hotZone)
        case .bottom:
            return CGRect(x: sf.minX, y: sf.minY, width: sf.width, height: hotZone)
        case .leading:
            return CGRect(x: sf.minX, y: sf.minY, width: hotZone, height: sf.height)
        case .trailing:
            return CGRect(x: sf.maxX - hotZone, y: sf.minY, width: hotZone, height: sf.height)
        }
    }
}
