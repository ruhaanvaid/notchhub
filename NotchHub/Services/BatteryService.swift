import Foundation
import IOKit.ps

/// Charging and low-battery pop-ups, from macOS power-source notifications (public IOKit API,
/// no permission). Shows a pop-up when the charger is plugged in, and warns once at 20% and
/// once at 10% while on battery. Macs without a battery never fire.
@MainActor
final class BatteryService {
    /// Called with `.battery(charging:)` and the charge level, 0...1.
    var onEvent: ((HUDKind, Double) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var wasOnAC: Bool?
    private var warned20 = false
    private var warned10 = false

    struct Reading: Equatable {
        var level: Double
        var onAC: Bool
    }

    func start() {
        // Starting state: no pop-up, and no warning for a level we were already below.
        if let reading = Self.read() {
            wasOnAC = reading.onAC
            warned20 = !reading.onAC && reading.level <= 0.20
            warned10 = !reading.onAC && reading.level <= 0.10
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.powerSourceChanged() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    func stop() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode) }
        runLoopSource = nil
    }

    private func powerSourceChanged() {
        guard let reading = Self.read() else { return }
        defer { wasOnAC = reading.onAC }
        guard AppSettings.shared.batteryAlerts else { return }

        if wasOnAC == false, reading.onAC {
            onEvent?(.battery(charging: true), reading.level)
        }
        if reading.onAC {
            warned20 = false
            warned10 = false
        } else if reading.level <= 0.10, !warned10 {
            warned10 = true
            warned20 = true
            onEvent?(.battery(charging: false), reading.level)
        } else if reading.level <= 0.20, !warned20 {
            warned20 = true
            onEvent?(.battery(charging: false), reading.level)
        }
    }

    /// The internal battery's charge and whether the Mac is on mains power.
    static func read() -> Reading? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }
            let onAC = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return Reading(level: min(1, Double(current) / Double(maximum)), onAC: onAC)
        }
        return nil
    }
}
