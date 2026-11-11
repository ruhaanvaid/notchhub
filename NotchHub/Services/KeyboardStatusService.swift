import AppKit
import Carbon

/// Caps Lock and keyboard-language pop-ups. Caps Lock comes from modifier-key events (the
/// Accessibility permission NotchHub already uses for the media keys); the input source from
/// the system's public "selected keyboard input source changed" notification.
@MainActor
final class KeyboardStatusService {
    var onEvent: ((HUDKind) -> Void)?

    private var monitors: [Any] = []
    private var inputObserver: NSObjectProtocol?
    private var capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
    private var inputSourceName = KeyboardStatusService.currentInputSourceName()

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.flagsChanged(event) }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }

        inputObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.inputSourceChanged() }
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        if let inputObserver { DistributedNotificationCenter.default().removeObserver(inputObserver) }
        inputObserver = nil
    }

    private func flagsChanged(_ event: NSEvent) {
        let on = event.modifierFlags.contains(.capsLock)
        guard on != capsLockOn else { return }
        capsLockOn = on
        if AppSettings.shared.keyboardAlerts { onEvent?(.capsLock(on: on)) }
    }

    private func inputSourceChanged() {
        let name = Self.currentInputSourceName()
        guard let name, name != inputSourceName else { return }
        inputSourceName = name
        if AppSettings.shared.keyboardAlerts { onEvent?(.inputSource(name: name)) }
    }

    static func currentInputSourceName() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
