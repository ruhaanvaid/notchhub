import AppKit

/// The menu-bar status item: an update notice (when there is one), Settings, Permissions…,
/// Check for Updates…, Launch at Login, Quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let updates: UpdateService
    private let onSettings: () -> Void
    private let onPermissions: () -> Void
    private let launchAtLoginItem: NSMenuItem
    private let updateItem: NSMenuItem
    private let updateSeparator = NSMenuItem.separator()

    init(updates: UpdateService, onSettings: @escaping () -> Void, onPermissions: @escaping () -> Void) {
        self.updates = updates
        self.onSettings = onSettings
        self.onPermissions = onPermissions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        self.updateItem = NSMenuItem(title: "", action: #selector(openUpdate), keyEquivalent: "")
        super.init()

        setUpdateBadge(false)

        let menu = NSMenu()
        menu.delegate = self

        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
        menu.addItem(updateItem)
        menu.addItem(updateSeparator)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let permissions = NSMenuItem(title: "Permissions…", action: #selector(openPermissions), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        let checkUpdates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdates.target = self
        menu.addItem(checkUpdates)

        menu.addItem(.separator())

        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit NotchHub", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        if updates.isInstalling, let release = updates.availableUpdate {
            updateItem.title = "Installing NotchHub \(release.version)…"
            updateItem.isEnabled = false
            updateItem.isHidden = false
            updateSeparator.isHidden = false
        } else if let release = updates.availableUpdate {
            updateItem.title = "Update Available: NotchHub \(release.version)…"
            updateItem.isEnabled = true
            updateItem.isHidden = false
            updateSeparator.isHidden = false
        } else {
            updateItem.isHidden = true
            updateSeparator.isHidden = true
        }
    }

    /// Adds a small dot to the menu-bar icon while an update is available.
    func setUpdateBadge(_ visible: Bool) {
        guard let button = statusItem.button else { return }
        guard let symbol = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: visible ? "NotchHub, update available" : "NotchHub"
        ) else {
            button.title = visible ? "NH•" : "NH"
            return
        }
        guard visible else {
            symbol.isTemplate = true
            button.image = symbol
            return
        }
        let size = symbol.size
        let badged = NSImage(size: NSSize(width: size.width + 3, height: size.height), flipped: false) { rect in
            symbol.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
            let dot: CGFloat = 5
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.maxX - dot, y: rect.maxY - dot, width: dot, height: dot)).fill()
            return true
        }
        badged.isTemplate = true
        badged.accessibilityDescription = "NotchHub, update available"
        button.image = badged
    }

    @objc private func openSettings() { onSettings() }

    @objc private func openPermissions() { onPermissions() }

    @objc private func openUpdate() {
        guard let release = updates.availableUpdate else { return }
        offerInstall(release)
    }

    /// "Install and Relaunch" / "Release Notes" / "Later".
    private func offerInstall(_ release: UpdateService.Release) {
        let alert = NSAlert()
        alert.messageText = "NotchHub \(release.version) is available"
        alert.informativeText = "You have \(UpdateService.currentVersion). NotchHub will download the update, replace itself, and reopen. Your settings, shelf and permissions stay as they are."
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "Later")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task {
                guard let error = await updates.install() else { return }
                let failure = NSAlert()
                failure.messageText = "Couldn't install the update"
                failure.informativeText = error
                failure.addButton(withTitle: "Download Manually…")
                failure.addButton(withTitle: "OK")
                NSApp.activate()
                if failure.runModal() == .alertFirstButtonReturn { updates.openReleasePage() }
            }
        case .alertSecondButtonReturn:
            updates.openReleasePage()
        default:
            break
        }
    }

    @objc private func checkForUpdates() {
        Task {
            let status = await updates.check()
            if case let .available(release) = status {
                offerInstall(release)
                return
            }
            let alert = NSAlert()
            switch status {
            case .upToDate:
                alert.messageText = "You're up to date"
                alert.informativeText = "NotchHub \(UpdateService.currentVersion) is the latest version."
                alert.addButton(withTitle: "OK")
            case let .failed(message):
                alert.messageText = "Couldn't check for updates"
                alert.informativeText = message
                alert.addButton(withTitle: "OK")
            case .idle, .checking, .available, .installing:
                return
            }
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Launch at Login"
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
