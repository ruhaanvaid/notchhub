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
