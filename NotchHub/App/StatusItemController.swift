import AppKit

/// The menu-bar status item: Settings, Permissions…, Launch at Login, Quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onSettings: () -> Void
    private let onPermissions: () -> Void
    private let launchAtLoginItem: NSMenuItem

    init(onSettings: @escaping () -> Void, onPermissions: @escaping () -> Void) {
        self.onSettings = onSettings
        self.onPermissions = onPermissions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        super.init()

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "NotchHub"
            )
            image?.isTemplate = true
            button.image = image
            if image == nil { button.title = "NH" }
        }

        let menu = NSMenu()
        menu.delegate = self

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let permissions = NSMenuItem(title: "Permissions…", action: #selector(openPermissions), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

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
    }

    @objc private func openSettings() { onSettings() }

    @objc private func openPermissions() { onPermissions() }

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
