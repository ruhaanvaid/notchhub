import AppKit
import SwiftUI

/// Hosts `SettingsView` in a regular window. The app is an accessory (no Dock icon),
/// so it has to activate itself for the window to come to the front.
@MainActor
final class SettingsWindowController {
    private let focus: FocusService
    private let permissions: PermissionsManager
    private let updates: UpdateService
    private let aiAlerts: AIAlertService
    private var window: NSWindow?

    init(focus: FocusService, permissions: PermissionsManager, updates: UpdateService, aiAlerts: AIAlertService) {
        self.focus = focus
        self.permissions = permissions
        self.updates = updates
        self.aiAlerts = aiAlerts
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(focus: focus, permissions: permissions, updates: updates, aiAlerts: aiAlerts)))
            window.title = "NotchHub Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
