import AppKit

/// Runs one notch panel per screen that should have one (the built-in notch, plus a pill on
/// the main external screen) and keeps them in sync. Each panel has its own `NotchState`, so
/// hovering one doesn't open the others; app-wide things (HUD, keep-awake dot, shelf,
/// settings) are pushed to all of them. Also hides panels on full-screen displays.
@MainActor
final class NotchCoordinator {
    private struct Entry {
        let state: NotchState
        let controller: NotchWindowController
    }

    private let context: PanelContext
    private let settings = AppSettings.shared
    private let fullScreen = FullScreenMonitor()
    private var entries: [CGDirectDisplayID: Entry] = [:]
    private var screenObserver: NSObjectProtocol?
    private var wasAnyExpanded = false

    /// Called when a pop-up is clicked.
    var onHUDTap: ((HUDKind) -> Void)?

    /// Called when the first panel opens or the last one closes.
    var onAnyExpandedChange: ((Bool) -> Void)?

    // App-wide state mirrored into every panel.
    private var indicatorVisible = false
    private var shelfHasItems = false
    private var live: LiveActivity?

    init(context: PanelContext) {
        self.context = context
    }

    func start() {
        reconcile()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }

        fullScreen.onChange = { [weak self] _ in self?.applyFullScreen() }
        fullScreen.start()

        // React to Settings. Read inside the tracking closure, act outside it, so the
        // tracking only follows these settings and not everything `reconcile` touches.
        observeChanges { [weak self] in
            _ = self?.settings.showMainScreenPill
            DispatchQueue.main.async { self?.reconcile() }
        }
        observeChanges { [weak self] in
            _ = self?.settings.shelfEnabled
            _ = self?.settings.showNowPlaying
            _ = self?.settings.showAudioControls
            _ = self?.settings.hideInFullScreen
            DispatchQueue.main.async {
                self?.applySharedState()
                self?.applyFullScreen()
            }
        }
    }

    func stop() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        fullScreen.stop()
        entries.values.forEach { $0.controller.stop() }
        entries.removeAll()
    }

    // MARK: - App-wide state

    func showHUD(_ kind: HUDKind, level: Double) {
        entries.values.forEach { $0.state.showHUD(kind, level: level) }
    }

    func setIndicatorVisible(_ visible: Bool) {
        indicatorVisible = visible
        entries.values.forEach { $0.state.indicatorVisible = visible }
    }

    /// Now playing and/or timer beside the closed notch; nil hides the wings.
    func setLive(_ live: LiveActivity?) {
        self.live = live
        entries.values.forEach { $0.state.live = live }
    }

    func setShelfHasItems(_ hasItems: Bool) {
        shelfHasItems = hasItems
        applySharedState()
    }

    private func applySharedState() {
        let contentHeight = NotchLayout.contentHeight(
            nowPlaying: settings.showNowPlaying, audioControls: settings.showAudioControls
        )
        for entry in entries.values {
            entry.state.shelfHasItems = shelfHasItems && settings.shelfEnabled
            entry.state.expandedContentHeight = contentHeight
            entry.state.indicatorVisible = indicatorVisible
            entry.state.live = live
        }
    }

    private func applyFullScreen() {
        for (id, entry) in entries {
            entry.controller.setSuppressed(settings.hideInFullScreen && fullScreen.fullScreenDisplays.contains(id))
        }
    }

    // MARK: - Screens

    /// Adds, moves, or removes panels to match the current screens and settings.
    private func reconcile() {
        let geometries = NotchGeometry.detectAll(includeMainScreenPill: settings.showMainScreenPill)
        let wanted = Set(geometries.map(\.displayID))

        for (id, entry) in entries where !wanted.contains(id) {
            entry.controller.stop()
            entries[id] = nil
        }

        for geometry in geometries {
            if let entry = entries[geometry.displayID] {
                if entry.state.geometry != geometry { entry.controller.apply(geometry) }
            } else {
                entries[geometry.displayID] = makeEntry(for: geometry)
            }
        }
        fullScreen.displays = geometries.map(\.displayID)
        applySharedState()
        applyFullScreen()
        updateAnyExpanded()
    }

    private func makeEntry(for geometry: NotchGeometry) -> Entry {
        let state = NotchState()
        state.onHUDTap = { [weak self] kind in self?.onHUDTap?(kind) }
        state.observeShapeChanges { [weak self] _ in self?.updateAnyExpanded() }

        let controller = NotchWindowController(state: state, context: context)
        controller.start()
        controller.apply(geometry)
        return Entry(state: state, controller: controller)
    }

    private func updateAnyExpanded() {
        let anyExpanded = entries.values.contains { $0.state.mode.isExpanded }
        guard anyExpanded != wasAnyExpanded else { return }
        wasAnyExpanded = anyExpanded
        onAnyExpandedChange?(anyExpanded)
    }
}
