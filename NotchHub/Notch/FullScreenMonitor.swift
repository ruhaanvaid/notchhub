import AppKit

/// Works out which displays currently show a full-screen app, so their notch panel can hide.
///
/// A display counts as full screen when another app's normal-level window covers all of it
/// and either the display's menu bar is gone (full-screen Spaces hide it) or the window starts
/// at the very top edge. A merely maximised window starts below a visible menu bar, so it
/// doesn't count. Only window bounds, layers and owners are read, which needs no permission.
@MainActor
final class FullScreenMonitor {
    /// Called with the set of full-screen displays whenever it changes.
    var onChange: ((Set<CGDirectDisplayID>) -> Void)?
    /// Displays to watch; set by the coordinator.
    var displays: [CGDirectDisplayID] = [] {
        didSet { check() }
    }
    private(set) var fullScreenDisplays: Set<CGDirectDisplayID> = []

    private var workspaceObservers: [NSObjectProtocol] = []
    private var timer: Timer?

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.check()
                    // Space switches animate; look again once they've settled.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.check() }
                }
            })
        }
        // Catches apps entering full screen without changing Space or activation.
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        check()
    }

    func stop() {
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        timer?.invalidate()
        timer = nil
    }

    func check() {
        let detected = Self.detect(displays: displays)
        guard detected != fullScreenDisplays else { return }
        fullScreenDisplays = detected
        onChange?(detected)
    }

    static func detect(displays: [CGDirectDisplayID]) -> Set<CGDirectDisplayID> {
        guard !displays.isEmpty,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return [] }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        let menuBarLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        let windows: [(layer: Int, pid: Int, rect: CGRect)] = info.compactMap { entry in
            guard let layer = entry[kCGWindowLayer as String] as? Int,
                  let pid = entry[kCGWindowOwnerPID as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict),
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0
            else { return nil }
            return (layer, pid, rect)
        }

        var result: Set<CGDirectDisplayID> = []
        for display in displays {
            let bounds = CGDisplayBounds(display)
            let hasMenuBar = windows.contains { window in
                window.layer == menuBarLevel
                    && abs(window.rect.minY - bounds.minY) <= 1
                    && window.rect.midX > bounds.minX && window.rect.midX < bounds.maxX
                    && window.rect.height < 80
            }
            let covered = windows.contains { window in
                guard window.layer == 0, window.pid != ownPID else { return false }
                let r = window.rect
                let coversWidth = abs(r.minX - bounds.minX) <= 1 && abs(r.width - bounds.width) <= 1
                let reachesBottom = abs(r.maxY - bounds.maxY) <= 1
                // Full-screen windows may start below the camera housing on notched displays.
                let startsNearTop = r.minY - bounds.minY <= 44
                guard coversWidth, reachesBottom, startsNearTop else { return false }
                return !hasMenuBar || r.minY - bounds.minY <= 1
            }
            if covered { result.insert(display) }
        }
        return result
    }
}
