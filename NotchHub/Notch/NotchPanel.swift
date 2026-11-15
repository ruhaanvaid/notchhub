import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits above the menu bar and never takes focus.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = Self.preferredLevel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        animationBehavior = .none
    }

    /// Just above the menu bar.
    static let preferredLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit normally pushes windows below the menu bar; the notch panel must stay on top of it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Hosting view that reacts to the first click even though the panel is never key.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Receives file drags over the notch panel.
@MainActor
protocol NotchDropDelegate: AnyObject {
    /// Return the operation to show, or [] to refuse the drag.
    func notchDragEntered(_ info: NSDraggingInfo) -> NSDragOperation
    func notchDragExited()
    func notchPerformDrop(_ info: NSDraggingInfo) -> Bool
}

/// Content view of the panel: hosts the SwiftUI view and is the file drop target. A plain
/// NSView is used as the destination so we don't depend on NSHostingView's own drag handling.
final class NotchContainerView: NSView {
    weak var dropDelegate: NotchDropDelegate?
    private var currentOperation: NSDragOperation = []

    init(hosting hostingView: NSView) {
        super.init(frame: .zero)
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
        // Make sure the drop lands here, not on the hosting view.
        hostingView.unregisterDraggedTypes()
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        currentOperation = dropDelegate?.notchDragEntered(sender) ?? []
        return currentOperation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        currentOperation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        currentOperation = []
        dropDelegate?.notchDragExited()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !currentOperation.isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { currentOperation = [] }
        return dropDelegate?.notchPerformDrop(sender) ?? false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        currentOperation = []
        dropDelegate?.notchDragExited()
    }
}

/// Scrolling over the panel. The panel is never key and NotchHub is usually not the active
/// app, and in that state AppKit doesn't reliably hand scroll events to the SwiftUI scroll
/// views inside it (the timer wheels didn't turn). The window controller catches scrolls over
/// the panel and passes them here, to go straight to the scroll view under the pointer.
@MainActor
enum NotchScrollRouter {
    /// Sends `event` to the scroll view at `windowPoint` in `root`'s window. Returns false when
    /// there is no scroll view there, so the event can carry on as usual.
    static func route(_ event: NSEvent, atWindowPoint windowPoint: NSPoint, in root: NSView) -> Bool {
        // hitTest takes a point in the receiver's superview's coordinates.
        let point = root.superview?.convert(windowPoint, from: nil) ?? windowPoint
        var view = root.hitTest(point)
        while let current = view, !(current is NSScrollView) { view = current.superview }
        guard let scrollView = view as? NSScrollView else { return false }
        scrollView.scrollWheel(with: scrollsVertically(scrollView) ? steppedForMouseWheel(event) : event)
        return true
    }

    private static func scrollsVertically(_ scrollView: NSScrollView) -> Bool {
        (scrollView.documentView?.frame.height ?? 0) > scrollView.contentView.bounds.height + 1
    }

    /// One click of a mouse wheel scrolls only a few points, which the wheels' snapping then
    /// undoes; make each click move one whole row. Trackpads (precise deltas) are untouched.
    static func steppedForMouseWheel(_ event: NSEvent) -> NSEvent {
        guard !event.hasPreciseScrollingDeltas, event.scrollingDeltaY != 0,
              let copy = event.cgEvent?.copy() else { return event }
        let direction: Double = event.scrollingDeltaY > 0 ? 1 : -1
        let row = Double(NotchLayout.timerRowHeight)
        copy.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        copy.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(row * direction))
        copy.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: row * direction)
        return NSEvent(cgEvent: copy) ?? event
    }
}
