import AppKit
import IOKit.hidsystem

enum MediaKey: Equatable {
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown
}

/// A decoded media-key press or release from an `NSSystemDefined` event.
struct MediaKeyEvent: Equatable {
    enum Modifiers: Equatable {
        /// No modifiers held.
        case none
        /// Shift+Option: fine-grained 1/64 steps, like macOS.
        case fineStep
        /// Any other combination (e.g. Option alone opens Sound settings). We pass these through.
        case other
    }

    var key: MediaKey
    var isDown: Bool
    var isRepeat: Bool
    var modifiers: Modifiers

    /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`
    static let auxControlButtonsSubtype: Int16 = 8

    init?(nsEvent: NSEvent, flags: CGEventFlags) {
        guard nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == Self.auxControlButtonsSubtype
        else { return nil }

        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = data1 & 0x0000_FFFF
        let keyState = (keyFlags & 0xFF00) >> 8

        switch keyCode {
        case NX_KEYTYPE_SOUND_UP: key = .volumeUp
        case NX_KEYTYPE_SOUND_DOWN: key = .volumeDown
        case NX_KEYTYPE_MUTE: key = .mute
        case NX_KEYTYPE_BRIGHTNESS_UP: key = .brightnessUp
        case NX_KEYTYPE_BRIGHTNESS_DOWN: key = .brightnessDown
        default: return nil
        }

        switch keyState {
        case 0x0A: isDown = true
        case 0x0B: isDown = false
        default: return nil
        }

        isRepeat = (keyFlags & 0x1) != 0

        let relevant = flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        if relevant.isEmpty {
            modifiers = .none
        } else if relevant == [.maskShift, .maskAlternate] {
            modifiers = .fineStep
        } else {
            modifiers = .other
        }
    }
}

/// Active CGEventTap on `NSSystemDefined` events. The handler returns true to swallow an
/// event (so Apple's overlay never appears) or false to pass it through untouched.
/// Every other event type passes through. Requires Accessibility permission.
@MainActor
final class MediaKeyTap {
    typealias Handler = @MainActor (MediaKeyEvent) -> Bool

    private let handler: Handler
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Returns false if the tap couldn't be created (usually: no Accessibility permission).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: refcon
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.runLoopSource = nil
    }

    /// Returns true to swallow the event.
    fileprivate func shouldSwallow(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        default:
            break
        }

        guard type.rawValue == UInt32(NSEvent.EventType.systemDefined.rawValue),
              let nsEvent = NSEvent(cgEvent: event),
              let keyEvent = MediaKeyEvent(nsEvent: nsEvent, flags: event.flags)
        else { return false }

        return handler(keyEvent)
    }
}

/// C callback. The run-loop source is on the main run loop, so this runs on the main thread.
private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()
    let swallow = MainActor.assumeIsolated {
        tap.shouldSwallow(type: type, event: event)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
