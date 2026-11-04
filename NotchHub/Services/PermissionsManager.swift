import AppKit
import ApplicationServices
import Observation
import SwiftUI

/// Tracks the Accessibility permission and shows the onboarding window.
/// The app works without the permission, just without the HUD replacement.
@Observable
@MainActor
final class PermissionsManager {
    private(set) var isAccessibilityTrusted = false

    /// Called whenever the trust state changes (including the first check).
    @ObservationIgnored var onAccessibilityChange: ((Bool) -> Void)?

    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private var hasReportedInitialState = false

    /// Polling interval while waiting for the grant, and afterwards to notice a revoke.
    private let waitingInterval: TimeInterval = 1
    private let grantedInterval: TimeInterval = 5

    /// Checks trust once, shows onboarding if needed, and starts polling.
    func start() {
        refresh()
        if !isAccessibilityTrusted {
            showOnboarding()
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        )
        let changed = trusted != isAccessibilityTrusted
        isAccessibilityTrusted = trusted

        if changed || !hasReportedInitialState {
            hasReportedInitialState = true
            onAccessibilityChange?(trusted)
            schedulePolling()
        } else if trusted {
            // Re-report while trusted so a tap that failed to start gets retried.
            onAccessibilityChange?(trusted)
        }
    }

    /// Adds NotchHub to the Accessibility list (unchecked) and opens that pane.
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        openAccessibilitySettings()
    }

    /// What System Settings calls the Accessibility privacy list. macOS 27 renamed it.
    static var accessibilityPaneName: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
            ? "Device Control and Data Access"
            : "Accessibility"
    }

    func openAccessibilitySettings() {
        // The newer link opens the pane directly (including its macOS 27 name); the older one
        // is the fallback for systems that don't recognise it.
        let links = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for link in links {
            if let url = URL(string: link), NSWorkspace.shared.open(url) { return }
        }
    }

    // MARK: - Onboarding window

    func showOnboarding() {
        if window == nil {
            let view = PermissionsOnboardingView(
                permissions: self,
                onClose: { [weak self] in self?.window?.close() }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "NotchHub Permissions"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Polling

    private func schedulePolling() {
        pollTimer?.invalidate()
        let interval = isAccessibilityTrusted ? grantedInterval : waitingInterval
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }
}
