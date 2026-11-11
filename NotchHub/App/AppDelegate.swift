import AppKit

/// Owns every long-lived service and controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissions = PermissionsManager()
    let volume = VolumeService()
    let brightness = BrightnessService()
    let outputs = AudioOutputService()
    let nowPlaying = NowPlayingService()
    let power = PowerService()
    let focus = FocusService()
    let shelf = ShelfStore()
    let updates = UpdateService()

    private var coordinator: NotchCoordinator?
    private var statusItemController: StatusItemController?
    private var mediaKeyController: MediaKeyController?
    private var mediaKeyTap: MediaKeyTap?
    private lazy var settingsWindowController = SettingsWindowController(
        focus: focus, permissions: permissions, updates: updates
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        volume.start()
        outputs.start()
        nowPlaying.start()
        focus.checkSetup()

        shelf.load()

        let context = PanelContext(
            nowPlaying: nowPlaying,
            volume: volume,
            outputs: outputs,
            power: power,
            focus: focus,
            shelf: shelf,
            openSettings: { [weak self] in self?.settingsWindowController.show() }
        )
        let coordinator = NotchCoordinator(context: context)
        coordinator.setShelfHasItems(!shelf.items.isEmpty)
        coordinator.onAnyExpandedChange = { [weak self] expanded in
            self?.panelOpenChanged(expanded)
        }
        coordinator.start()
        self.coordinator = coordinator

        shelf.onHasItemsChange = { [weak coordinator] hasItems in
            coordinator?.setShelfHasItems(hasItems)
        }
        power.onChange = { [weak coordinator] on in
            coordinator?.setIndicatorVisible(on)
        }

        let keys = MediaKeyController(volume: volume, brightness: brightness) { [weak coordinator] kind, level in
            coordinator?.showHUD(kind, level: level)
        }
        mediaKeyController = keys
        mediaKeyTap = MediaKeyTap { [weak keys] event in
            keys?.handle(event) ?? false
        }

        // Turning a section off in Settings also stops what it was doing.
        observeChanges { [weak self] in
            guard let self else { return }
            let keepAwakeShown = AppSettings.shared.showKeepAwake
            let nowPlayingShown = AppSettings.shared.showNowPlaying
            DispatchQueue.main.async {
                if !keepAwakeShown { self.power.setKeepAwake(false) }
                _ = nowPlayingShown
                self.nowPlaying.refresh()
            }
        }

        let statusItem = StatusItemController(
            updates: updates,
            onSettings: { [weak self] in self?.settingsWindowController.show() },
            onPermissions: { [weak self] in self?.permissions.showOnboarding() }
        )

        // The tap can only exist while Accessibility is granted; follow the permission live.
        statusItemController = statusItem
        updates.onStatusChange = { [weak statusItem] status in
            if case .available = status {
                statusItem?.setUpdateBadge(true)
            } else if status == .upToDate {
                statusItem?.setUpdateBadge(false)
            }
        }
        updates.start()

        permissions.onAccessibilityChange = { [weak self] trusted in
            self?.updateMediaKeyTap(trusted: trusted)
        }
        permissions.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeyTap?.stop()
        updates.stop()
        power.setKeepAwake(false)
        nowPlaying.stop()
        outputs.stop()
        volume.stop()
        coordinator?.stop()
    }

    /// Refreshes panel data when a panel opens; lets now-playing stop polling when all close.
    private func panelOpenChanged(_ expanded: Bool) {
        nowPlaying.setPanelOpen(expanded)
        if expanded {
            volume.refresh()
            outputs.reload()
            shelf.pruneMissing()
        }
    }

    private func updateMediaKeyTap(trusted: Bool) {
        guard let mediaKeyTap else { return }
        if trusted {
            if !mediaKeyTap.isRunning, !mediaKeyTap.start() {
                NSLog("NotchHub: Accessibility is granted but the event tap could not be created.")
            }
        } else {
            mediaKeyTap.stop()
        }
    }
}
