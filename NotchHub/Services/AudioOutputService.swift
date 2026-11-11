import CoreAudio
import Observation

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let transportType: UInt32

    /// Compact name for tight spaces: "MacBook Pro Speakers" → "Speakers".
    var shortName: String {
        for prefix in ["MacBook Pro ", "MacBook Air ", "MacBook ", "iMac ", "Mac mini ", "Mac Studio "]
        where name.hasPrefix(prefix) && name.count > prefix.count {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    /// Icon for the "connected" pop-up.
    var connectionSymbol: String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("speaker") || lower.contains("homepod") || lower.contains("sonos") { return "hifispeaker.fill" }
        return isBluetooth ? "headphones" : symbolName
    }

    var symbolName: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return "laptopcomputer"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return name.localizedCaseInsensitiveContains("airpods") ? "airpods" : "headphones"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt:
            return "hifispeaker"
        default:
            return "speaker.wave.2"
        }
    }
}

/// Lists CoreAudio output devices and switches the default output. Follows device changes.
@Observable
@MainActor
final class AudioOutputService {
    private(set) var devices: [AudioOutputDevice] = []
    private(set) var defaultDeviceID: AudioDeviceID?

    var currentDevice: AudioOutputDevice? {
        devices.first { $0.id == defaultDeviceID }
    }

    @ObservationIgnored private var listeners: [CoreAudioListener] = []
    /// Called when a Bluetooth audio device (AirPods, headphones, speakers) appears.
    @ObservationIgnored var onDeviceConnected: ((AudioOutputDevice) -> Void)?
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var recentlyAnnounced: [String: Date] = [:]

    func start() {
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            listeners.append(CoreAudioListener(
                object: AudioHAL.systemObject,
                address: AudioHAL.address(selector)
            ) { [weak self] in
                self?.reload()
            })
        }
        reload()
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func reload() {
        let ids = AudioHAL.getArray(
            AudioHAL.systemObject, AudioHAL.address(kAudioHardwarePropertyDevices), of: AudioDeviceID.self
        )
        let outputs = ids.compactMap(Self.outputDevice)
        if hasLoaded {
            // New devices since the last look. Bluetooth devices can flicker while connecting,
            // so the same name isn't announced twice within 10 seconds.
            let known = Set(devices.map(\.id))
            for device in outputs where !known.contains(device.id) && device.isBluetooth {
                if let last = recentlyAnnounced[device.name], Date().timeIntervalSince(last) < 10 { continue }
                recentlyAnnounced[device.name] = Date()
                onDeviceConnected?(device)
            }
        }
        hasLoaded = true
        if outputs != devices { devices = outputs }
        let current = AudioHAL.defaultOutputDevice
        if current != defaultDeviceID { defaultDeviceID = current }
    }

    func select(_ device: AudioOutputDevice) {
        AudioHAL.set(AudioHAL.systemObject, AudioHAL.address(kAudioHardwarePropertyDefaultOutputDevice), device.id)
        reload()
    }

    private static func outputDevice(_ id: AudioDeviceID) -> AudioOutputDevice? {
        let streams = AudioHAL.getArray(
            id, AudioHAL.address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput),
            of: AudioStreamID.self
        )
        guard !streams.isEmpty else { return nil }

        let hidden = AudioHAL.get(id, AudioHAL.address(kAudioDevicePropertyIsHidden), initial: UInt32(0)) ?? 0
        guard hidden == 0 else { return nil }

        guard let name = AudioHAL.string(id, AudioHAL.address(kAudioObjectPropertyName)) else { return nil }
        let transport = AudioHAL.get(id, AudioHAL.address(kAudioDevicePropertyTransportType), initial: UInt32(0)) ?? 0
        return AudioOutputDevice(id: id, name: name, transportType: transport)
    }
}
