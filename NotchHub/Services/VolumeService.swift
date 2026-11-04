import AudioToolbox
import CoreAudio
import Observation

/// Volume and mute on the default output device, via CoreAudio. Publishes the current
/// level for the panel's slider and follows default-device and volume changes.
@Observable
@MainActor
final class VolumeService {
    /// Normal and Shift+Option step counts, matching macOS.
    static let coarseSteps: Float = 16
    static let fineSteps: Float = 64

    /// Device volume, 0...1 (independent of mute).
    private(set) var volume: Double = 0
    private(set) var isMuted = false
    /// False for outputs without software volume (some HDMI/DisplayPort devices).
    private(set) var canSetVolume = false
    private(set) var canSetMute = false

    /// The level to show in the UI: 0 while muted.
    var displayedLevel: Double { isMuted ? 0 : volume }

    @ObservationIgnored private var defaultDeviceListener: CoreAudioListener?
    @ObservationIgnored private var deviceListeners: [CoreAudioListener] = []

    private static let volumeAddress = AudioHAL.address(
        kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput
    )
    private static let muteAddress = AudioHAL.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)

    func start() {
        defaultDeviceListener = CoreAudioListener(
            object: AudioHAL.systemObject,
            address: AudioHAL.address(kAudioHardwarePropertyDefaultOutputDevice)
        ) { [weak self] in
            self?.bindToDefaultDevice()
        }
        bindToDefaultDevice()
    }

    func stop() {
        defaultDeviceListener?.remove()
        deviceListeners.forEach { $0.remove() }
        deviceListeners.removeAll()
    }

    /// Re-reads everything from CoreAudio.
    func refresh() {
        guard let device = AudioHAL.defaultOutputDevice else {
            canSetVolume = false
            canSetMute = false
            return
        }
        canSetVolume = AudioHAL.isSettable(device, Self.volumeAddress)
        canSetMute = AudioHAL.isSettable(device, Self.muteAddress)
        volume = Double(AudioHAL.get(device, Self.volumeAddress, initial: Float32(0)) ?? 0)
        isMuted = (AudioHAL.get(device, Self.muteAddress, initial: UInt32(0)) ?? 0) != 0
    }

    private func bindToDefaultDevice() {
        deviceListeners.forEach { $0.remove() }
        deviceListeners.removeAll()
        if let device = AudioHAL.defaultOutputDevice {
            for address in [Self.volumeAddress, Self.muteAddress] where AudioHAL.has(device, address) {
                deviceListeners.append(CoreAudioListener(object: device, address: address) { [weak self] in
                    self?.refresh()
                })
            }
        }
        refresh()
    }

    // MARK: - Writing

    func setMuted(_ muted: Bool) {
        guard let device = AudioHAL.defaultOutputDevice else { return }
        AudioHAL.set(device, Self.muteAddress, UInt32(muted ? 1 : 0))
        refresh()
    }

    /// Sets the volume; moving it above zero unmutes, like the system slider.
    func setVolume(_ value: Double) {
        guard let device = AudioHAL.defaultOutputDevice else { return }
        let clamped = min(max(value, 0), 1)
        if clamped > 0, isMuted, canSetMute {
            AudioHAL.set(device, Self.muteAddress, UInt32(0))
        }
        AudioHAL.set(device, Self.volumeAddress, Float32(clamped))
        refresh()
    }

    /// Steps the volume like the hardware keys do. Returns the level to display.
    func step(up: Bool, fine: Bool) -> Double {
        refresh()
        let steps = fine ? Self.fineSteps : Self.coarseSteps
        let index = (Float(volume) * steps).rounded() + (up ? 1 : -1)
        let newValue = min(max(index / steps, 0), 1)

        if up, isMuted, canSetMute, let device = AudioHAL.defaultOutputDevice {
            AudioHAL.set(device, Self.muteAddress, UInt32(0))
        }
        if let device = AudioHAL.defaultOutputDevice {
            AudioHAL.set(device, Self.volumeAddress, Float32(newValue))
        }
        refresh()
        return displayedLevel
    }

    /// Returns the level to display.
    func toggleMute() -> Double {
        refresh()
        setMuted(!isMuted)
        return displayedLevel
    }
}
