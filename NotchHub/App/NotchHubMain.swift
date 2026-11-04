import AppKit

/// Plain AppKit entry point. A SwiftUI `App` adds little for a menu-bar utility and makes
/// opening a Settings window from AppKit awkward, so the app is driven by `AppDelegate`.
@main
enum NotchHubMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        // `run()` never returns, so `delegate` stays alive for the life of the process.
        _ = delegate
    }
}
