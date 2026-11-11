import AppKit
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.notchhub.app", category: "notch")

/// Owns one notch panel (the hardware notch, or a pill on a screen without one): positions it,
/// decides when it accepts the mouse, and drives hover-expand / collapse. `NotchCoordinator`
/// creates one per screen and feeds it that screen's geometry.
@MainActor
final class NotchWindowController: NotchDropDelegate {
    private let state: NotchState
    private let context: PanelContext
    private var panel: NotchPanel?
    private var eventMonitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var hoverTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    /// Re-checks the cursor while the notch is open, in case no mouse event arrives as it leaves.
    private var watchdog: Timer?
    /// A menu (e.g. the output switcher) is open: its items lie outside the shape.
    private var isMenuTracking = false
    /// The button went down on the panel (e.g. dragging the volume slider) and is still held.
    private var isMouseDownInside = false
    /// Last hit-test result, for logging transitions only.
    private var lastInside = false
    /// A full-screen app covers this screen: stay hidden except to flash the HUD.
    private var isSuppressed = false

    /// While true the panel must not collapse or start ignoring the mouse.
    private var isInteractionLocked: Bool {
        // Menus and drag sessions swallow the mouse-up, so confirm against the real button
        // state instead of trusting that a mouse-up event arrived.
        if isMouseDownInside, NSEvent.pressedMouseButtons & 1 == 0 {
            isMouseDownInside = false
        }
        return isMenuTracking || isMouseDownInside
    }

    private let hoverDelay: Duration = .milliseconds(150)
    /// Forgiving enough that overshooting the edge doesn't snap the panel shut.
    private let collapseDelay: Duration = .milliseconds(300)

    init(state: NotchState, context: PanelContext) {
        self.state = state
        self.context = context
    }

    func start() {
        let panel = NotchPanel(contentRect: .zero)
        let hostingView = NotchHostingView(rootView: NotchRootView(state: state, context: context))
        hostingView.sizingOptions = []
        let container = NotchContainerView(hosting: hostingView)
        container.dropDelegate = self
        panel.contentView = container
        // The panel is always black, so menus it opens should be dark too.
        panel.appearance = NSAppearance(named: .darkAqua)
        self.panel = panel

        // The shape changes size with the mode (e.g. HUD wings appear or vanish under a resting
        // cursor), so re-check pass-through without starting a hover.
        state.observeShapeChanges { [weak self] _ in
            self?.updateMousePassThrough()
            self?.updateVisibility()
        }

        installEventMonitors()
        observeNotifications()
    }

    func stop() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        hoverTask?.cancel()
        collapseTask?.cancel()
        watchdog?.invalidate()
        panel?.orderOut(nil)
    }

    // MARK: - Geometry

    /// Positions the panel for this screen's notch or pill.
    func apply(_ geometry: NotchGeometry) {
        guard let panel else { return }
        state.geometry = geometry
        log.info("display \(geometry.displayID, privacy: .public): notch \(geometry.notchSize.width, privacy: .public)x\(geometry.notchSize.height, privacy: .public) centerX=\(geometry.centerX, privacy: .public) topY=\(geometry.topY, privacy: .public) hardware=\(geometry.hasHardwareNotch, privacy: .public)")
        let size = NotchLayout.windowSize(for: geometry)
        let frame = NSRect(
            x: (geometry.centerX - size.width / 2).rounded(),
            y: geometry.topY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
        if !isSuppressed { panel.orderFrontRegardless() }
        log.info("display \(geometry.displayID, privacy: .public): panel level=\(panel.level.rawValue, privacy: .public) visible=\(panel.isVisible, privacy: .public) onActiveSpace=\(panel.isOnActiveSpace, privacy: .public) occlusion=\(panel.occlusionState.rawValue, privacy: .public) window=\(panel.windowNumber, privacy: .public)")
    }

    private func observeNotifications() {
        let center = NotificationCenter.default

        // Re-assert ordering after Space switches so the panel never ends up behind anything.
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isSuppressed else { return }
                self.panel?.orderFrontRegardless()
            }
        })

        // Keep the panel open while one of its menus is showing.
        observers.append(center.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.mode.isExpanded else { return }
                self.isMenuTracking = true
                self.collapseTask?.cancel()
                self.collapseTask = nil
            }
        })
        observers.append(center.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isMenuTracking else { return }
                self.isMenuTracking = false
                self.mouseMoved()
            }
        })
    }

    // MARK: - Mouse

    private func installEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]

        // Events going to other apps (no Accessibility permission needed for mouse events).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) {
            eventMonitors.append(global)
        }

        // Events going to our own panel while it accepts the mouse.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            eventMonitors.append(local)
        }

        // A press on the panel locks it open until release, so dragging the slider past the
        // edge doesn't collapse it mid-drag. Only presses on our own panel are local events.
        if let down = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.isMouseDownInside = true }
            return event
        }) {
            eventMonitors.append(down)
        }
        if let upLocal = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseReleased() }
            return event
        }) {
            eventMonitors.append(upLocal)
        }
        if let upGlobal = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseReleased() }
        }) {
            eventMonitors.append(upGlobal)
        }
    }

    private func mouseReleased() {
        guard isMouseDownInside else { return }
        isMouseDownInside = false
        mouseMoved()
    }

    @discardableResult
    private func updateMousePassThrough() -> Bool {
        let inside = shapeContains(NSEvent.mouseLocation)
        // Never drop the mouse in the middle of an interaction with the panel.
        panel?.ignoresMouseEvents = !inside && !isInteractionLocked
        return inside
    }

    /// Hides the panel while a full-screen app covers its screen.
    func setSuppressed(_ suppressed: Bool) {
        guard suppressed != isSuppressed else { return }
        isSuppressed = suppressed
        log.info("display \(self.state.geometry?.displayID ?? 0, privacy: .public): \(suppressed ? "hidden for full screen" : "shown", privacy: .public)")
        if suppressed {
            hoverTask?.cancel()
            hoverTask = nil
            state.isDropTargeted = false
            if state.mode.isExpanded { state.collapse() }
        }
        updateVisibility()
    }

    /// On screen unless suppressed; a suppressed panel still shows the HUD while it's up.
    private func updateVisibility() {
        guard let panel, state.geometry != nil else { return }
        let shouldShow = !isSuppressed || state.mode.isHUD
        if shouldShow, !panel.isVisible {
            panel.orderFrontRegardless()
        } else if !shouldShow, panel.isVisible {
            panel.orderOut(nil)
            panel.ignoresMouseEvents = true
        }
    }

    private func mouseMoved() {
        guard !isSuppressed else { return }
        let wasInside = lastInside
        let inside = updateMousePassThrough()
        lastInside = inside
        if inside != wasInside {
            let p = NSEvent.mouseLocation
            log.info("display \(self.state.geometry?.displayID ?? 0, privacy: .public): pointer \(inside ? "entered" : "left", privacy: .public) shape at (\(p.x, privacy: .public), \(p.y, privacy: .public)), mode=\(String(describing: self.state.mode), privacy: .public)")
        }

        if inside {
            collapseTask?.cancel()
            collapseTask = nil
            if !state.mode.isExpanded, !state.mode.isAIAlert, hoverTask == nil {
                scheduleExpand()
            }
        } else {
            hoverTask?.cancel()
            hoverTask = nil
            if state.mode.isExpanded, collapseTask == nil, !isInteractionLocked {
                scheduleCollapse()
            }
        }
    }

    private func scheduleExpand() {
        hoverTask = Task { [weak self, hoverDelay] in
            try? await Task.sleep(for: hoverDelay)
            guard !Task.isCancelled, let self else { return }
            self.hoverTask = nil
            guard self.shapeContains(NSEvent.mouseLocation) else { return }
            log.info("expanding")
            self.state.expand()
            self.startWatchdog()
        }
    }

    private func scheduleCollapse() {
        collapseTask = Task { [weak self, collapseDelay] in
            try? await Task.sleep(for: collapseDelay)
            guard !Task.isCancelled, let self else { return }
            self.collapseTask = nil
            guard !self.isInteractionLocked, !self.shapeContains(NSEvent.mouseLocation) else { return }
            self.state.isDropTargeted = false
            log.info("collapsing")
            self.state.collapse()
            self.stopWatchdog()
        }
    }

    private func startWatchdog() {
        guard watchdog == nil else { return }
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    /// Hit-tests a global screen point against the shape for the current mode.
    private func shapeContains(_ point: NSPoint) -> Bool {
        guard let geometry = state.geometry, let metrics = state.metrics else { return false }
        let size = metrics.shapeSize
        let originX = geometry.centerX - size.width / 2
        // Convert to shape-local coordinates with y pointing down, as SwiftUI draws it.
        let local = CGPoint(x: point.x - originX, y: geometry.topY - point.y)
        let bounds = CGRect(origin: .zero, size: size)
        guard bounds.insetBy(dx: -0.5, dy: -0.5).contains(local) else { return false }
        return NotchShape(topRadius: metrics.topRadius, bottomRadius: metrics.bottomRadius)
            .path(in: bounds)
            .contains(local)
    }
    // MARK: - File drops

    func notchDragEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        // Ignore drags that started on our own shelf, and anything that isn't a file.
        guard AppSettings.shared.shelfEnabled,
              info.draggingSource == nil,
              !Self.fileURLs(in: info).isEmpty
        else { return [] }
        hoverTask?.cancel()
        hoverTask = nil
        collapseTask?.cancel()
        collapseTask = nil
        state.isDropTargeted = true
        if !state.mode.isExpanded {
            state.expand()
            startWatchdog()
        }
        return .copy
    }

    func notchDragExited() {
        state.isDropTargeted = false
        mouseMoved()
    }

    func notchPerformDrop(_ info: NSDraggingInfo) -> Bool {
        let urls = Self.fileURLs(in: info)
        state.isDropTargeted = false
        return context.shelf.add(urls) > 0
    }

    private static func fileURLs(in info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (objects as? [URL]) ?? []
    }
}
