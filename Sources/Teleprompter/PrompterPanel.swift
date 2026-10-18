import AppKit

/// Borderless, always-on-top panel that is excluded from screen sharing and screenshots.
final class PrompterPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    var scrollHandler: ((NSEvent) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 520, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        sharingType = .none              // hidden from screen sharing & screenshots
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let handler = keyHandler, handler(event) { return }
        if event.type == .scrollWheel, let handler = scrollHandler { handler(event); return }
        super.sendEvent(event)
    }
}

/// Reports mouse enter/exit even when the app is not active.
final class HoverTrackingView: NSView {
    var onChange: ((Bool) -> Void)?
    private var area: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let a = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(a)
        area = a
    }

    override func mouseEntered(with event: NSEvent) { onChange?(true) }
    override func mouseExited(with event: NSEvent) { onChange?(false) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Drag this view to move the floating window.
final class DragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

/// Bottom-right grip that resizes the floating window, keeping the top-left corner fixed.
final class ResizeGripView: NSView {
    var onResize: ((NSSize) -> Void)?
    private var startMouse: NSPoint = .zero
    private var startFrame: NSRect = .zero

    override func mouseDown(with event: NSEvent) {
        startMouse = NSEvent.mouseLocation
        startFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        let w = startFrame.width + (now.x - startMouse.x)
        let h = startFrame.height - (now.y - startMouse.y)
        onResize?(NSSize(width: w, height: h))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.35).setStroke()
        let p = NSBezierPath()
        p.lineWidth = 1.5
        for i in 1...3 {
            let d = CGFloat(i) * 4
            p.move(to: NSPoint(x: bounds.maxX - d - 2, y: bounds.minY + 2))
            p.line(to: NSPoint(x: bounds.maxX - 2, y: bounds.minY + d + 2))
        }
        p.stroke()
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
}
