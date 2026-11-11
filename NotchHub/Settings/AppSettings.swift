import Foundation
import Observation

/// User preferences, persisted in UserDefaults. Observable, so views and controllers that
/// read a setting update when it changes.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    // HUD
    var replaceVolumeHUD: Bool { didSet { store(replaceVolumeHUD, Key.replaceVolumeHUD) } }
    var replaceBrightnessHUD: Bool { didSet { store(replaceBrightnessHUD, Key.replaceBrightnessHUD) } }
    /// Seconds the HUD stays up after the last key press.
    var hudDuration: Double { didSet { store(hudDuration, Key.hudDuration) } }

    // Panel sections
    var showNowPlaying: Bool { didSet { store(showNowPlaying, Key.showNowPlaying) } }
    /// Also look for YouTube in Safari and Chromium browsers.
    var includeBrowserMedia: Bool { didSet { store(includeBrowserMedia, Key.includeBrowserMedia) } }
    var showAudioControls: Bool { didSet { store(showAudioControls, Key.showAudioControls) } }
    var showKeepAwake: Bool { didSet { store(showKeepAwake, Key.showKeepAwake) } }
    var showFocus: Bool { didSet { store(showFocus, Key.showFocus) } }
    var shelfEnabled: Bool { didSet { store(shelfEnabled, Key.shelfEnabled) } }

    // Screens
    var showMainScreenPill: Bool { didSet { store(showMainScreenPill, Key.showMainScreenPill) } }
    var hideInFullScreen: Bool { didSet { store(hideInFullScreen, Key.hideInFullScreen) } }

    // Updates
    /// Once a day, ask GitHub whether a newer release exists.
    var checkForUpdates: Bool { didSet { store(checkForUpdates, Key.checkForUpdates) } }

    static let hudDurationRange: ClosedRange<Double> = 0.5...5

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let replaceVolumeHUD = "replaceVolumeHUD"
        static let replaceBrightnessHUD = "replaceBrightnessHUD"
        static let hudDuration = "hudDuration"
        static let showNowPlaying = "showNowPlaying"
        static let includeBrowserMedia = "includeBrowserMedia"
        static let showAudioControls = "showAudioControls"
        static let showKeepAwake = "showKeepAwake"
        static let showFocus = "showFocus"
        static let shelfEnabled = "shelfEnabled"
        static let showMainScreenPill = "showMainScreenPill"
        static let hideInFullScreen = "hideInFullScreen"
        static let checkForUpdates = "checkForUpdates"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.replaceVolumeHUD: true,
            Key.replaceBrightnessHUD: true,
            Key.hudDuration: 1.5,
            Key.showNowPlaying: true,
            Key.includeBrowserMedia: true,
            Key.showAudioControls: true,
            Key.showKeepAwake: true,
            Key.showFocus: true,
            Key.shelfEnabled: true,
            Key.showMainScreenPill: true,
            Key.hideInFullScreen: true,
            Key.checkForUpdates: true,
        ])
        replaceVolumeHUD = defaults.bool(forKey: Key.replaceVolumeHUD)
        replaceBrightnessHUD = defaults.bool(forKey: Key.replaceBrightnessHUD)
        hudDuration = min(max(defaults.double(forKey: Key.hudDuration), Self.hudDurationRange.lowerBound),
                          Self.hudDurationRange.upperBound)
        showNowPlaying = defaults.bool(forKey: Key.showNowPlaying)
        includeBrowserMedia = defaults.bool(forKey: Key.includeBrowserMedia)
        showAudioControls = defaults.bool(forKey: Key.showAudioControls)
        showKeepAwake = defaults.bool(forKey: Key.showKeepAwake)
        showFocus = defaults.bool(forKey: Key.showFocus)
        shelfEnabled = defaults.bool(forKey: Key.shelfEnabled)
        showMainScreenPill = defaults.bool(forKey: Key.showMainScreenPill)
        hideInFullScreen = defaults.bool(forKey: Key.hideInFullScreen)
        checkForUpdates = defaults.bool(forKey: Key.checkForUpdates)
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}

/// Runs `body` now and again whenever an observable value it read changes.
@MainActor
func observeChanges(_ body: @escaping @MainActor () -> Void) {
    withObservationTracking {
        body()
    } onChange: {
        Task { @MainActor in observeChanges(body) }
    }
}
