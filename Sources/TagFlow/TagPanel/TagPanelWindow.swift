import AppKit

final class TagPanelWindow: NSWindow {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    // Override the designated initializer to prevent Swift from generating an
    // _unimplementedInitializer stub that crashes when AppKit routes through it.
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style,
                   backing: backingStoreType, defer: flag)
    }

    required init?(coder: NSCoder) {
        super.init(contentRect: .zero, styleMask: .borderless,
                   backing: .buffered, defer: false)
    }

    // Borderless windows return false by default; override so SwiftUI hosted views
    // (e.g. the new-tag TextField) can receive keyboard focus without warnings.
    override var canBecomeKey: Bool { true }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        level = .floating
    }
}
