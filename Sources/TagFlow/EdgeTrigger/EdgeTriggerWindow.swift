import AppKit

/// A short pocket strip anchored to a screen edge. The user can drag it to any edge.
final class EdgeTriggerWindow: NSWindow {
    let edge: ScreenEdge
    let targetScreen: NSScreen

    static let thickness: CGFloat = 16   // perpendicular to edge
    static let length: CGFloat   = 200   // along the edge

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
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
    }

    /// The pocket rect: a short strip flush with the given edge, centered at `centerRatio` (0…1).
    static func pocketRect(for edge: ScreenEdge, screen: NSScreen, centerRatio: CGFloat = 0.5) -> CGRect {
        let sf = screen.frame
        let vf = screen.visibleFrame
        let t = thickness, l = length

        switch edge {
        case .trailing:
            let cy = vf.minY + vf.height * centerRatio
            return CGRect(x: sf.maxX - t, y: cy - l / 2, width: t, height: l)
        case .leading:
            let cy = vf.minY + vf.height * centerRatio
            return CGRect(x: sf.minX, y: cy - l / 2, width: t, height: l)
        case .top:
            let cx = sf.minX + sf.width * centerRatio
            return CGRect(x: cx - l / 2, y: vf.maxY - t, width: l, height: t)
        case .bottom:
            let cx = sf.minX + sf.width * centerRatio
            return CGRect(x: cx - l / 2, y: sf.minY, width: l, height: t)
        }
    }
}
