import Foundation

/// Routes media keys from `MediaKeyTap` to the volume/brightness services and the HUD.
/// A key is swallowed only when the matching service can fully handle it; otherwise it
/// is passed through so macOS handles it as usual.
@MainActor
final class MediaKeyController {
    private let volume: VolumeService
    private let brightness: BrightnessService
    /// Shows the HUD on every notch panel.
    private let showHUD: (HUDKind, Double) -> Void

    init(volume: VolumeService, brightness: BrightnessService, showHUD: @escaping (HUDKind, Double) -> Void) {
        self.volume = volume
        self.brightness = brightness
        self.showHUD = showHUD
    }

    /// Returns true to swallow the event. Key-ups are swallowed whenever the matching key-down
    /// would be, so the system never sees half a key press.
    func handle(_ event: MediaKeyEvent) -> Bool {
        guard event.modifiers != .other else { return false }
        let fine = event.modifiers == .fineStep
        if event.key == .volumeUp || event.key == .volumeDown || event.key == .mute {
            // Cheap, and guarantees the capability checks below reflect the current device.
            volume.refresh()
        }

        switch event.key {
        case .volumeUp, .volumeDown:
            guard AppSettings.shared.replaceVolumeHUD, volume.canSetVolume else { return false }
            if event.isDown {
                let level = volume.step(up: event.key == .volumeUp, fine: fine)
                showHUD(.volume, level)
            }
            return true

        case .mute:
            guard AppSettings.shared.replaceVolumeHUD, volume.canSetMute else { return false }
            if event.isDown, !event.isRepeat {
                showHUD(.volume, volume.toggleMute())
            }
            return true

        case .brightnessUp, .brightnessDown:
            guard AppSettings.shared.replaceBrightnessHUD, brightness.canAdjust else { return false }
            if event.isDown, let level = brightness.step(up: event.key == .brightnessUp, fine: fine) {
                showHUD(.brightness, level)
            }
            return true
        }
    }
}
