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
    let battery = BatteryService()
    let keyboard = KeyboardStatusService()
    let timer = TimerService()

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
            timer: timer,
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
            switch status {
            case .available, .installing:
                statusItem?.setUpdateBadge(true)
            case .upToDate:
                statusItem?.setUpdateBadge(false)
            default:
                break
            }
        }
        updates.start()

        // Pop-ups from the notch: charger, low battery, headphones, Caps Lock, keyboard, timer.
        battery.onEvent = { [weak coordinator] kind, level in coordinator?.showHUD(kind, level: level) }
        battery.start()
        keyboard.onEvent = { [weak coordinator] kind in coordinator?.showHUD(kind, level: 0) }
        keyboard.start()
        outputs.onDeviceConnected = { [weak coordinator] device in
            guard AppSettings.shared.deviceAlerts else { return }
            coordinator?.showHUD(.device(name: device.name, symbol: device.connectionSymbol), level: 0)
        }
        timer.onFinished = { [weak coordinator] in coordinator?.showHUD(.timerDone, level: 0) }

        // Live activity beside the closed notch: what's playing, and/or a running timer.
        observeChanges { [weak self] in
            guard let self else { return }
            let settings = AppSettings.shared
            let track = self.nowPlaying.track
            let showsMedia = settings.liveNowPlaying && settings.showNowPlaying && (track?.isPlaying ?? false)
            let timerEnd = settings.showTimer ? self.timer.endDate : nil
            let live: LiveActivity? = (showsMedia || timerEnd != nil)
                ? LiveActivity(
                    artwork: showsMedia ? self.nowPlaying.artwork : nil,
                    tint: self.nowPlaying.artworkTint,
                    isPlaying: showsMedia,
                    timerEnd: timerEnd,
                    showsMedia: showsMedia
                )
                : nil
            DispatchQueue.main.async { [weak self] in self?.coordinator?.setLive(live) }
        }

        permissions.onAccessibilityChange = { [weak self] trusted in
            self?.updateMediaKeyTap(trusted: trusted)
        }
        permissions.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeyTap?.stop()
        battery.stop()
        keyboard.stop()
        timer.cancel()
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
