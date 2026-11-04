import AppKit

/// Where the notch is and how big it is, in global AppKit coordinates (origin bottom-left, y up).
struct NotchGeometry: Equatable {
    /// The display this notch (or pill) is on.
    var displayID: CGDirectDisplayID
    /// Frame of the screen that hosts the notch (or the fallback pill).
    var screenFrame: CGRect
    /// Size of the hardware notch, or of the fallback pill on Macs without one.
    var notchSize: CGSize
    /// Horizontal center of the notch in global coordinates.
    var centerX: CGFloat
    /// False when showing the fallback pill.
    var hasHardwareNotch: Bool

    /// Top edge of the screen; the notch hangs down from here.
    var topY: CGFloat { screenFrame.maxY }

    /// Size of the pill shown on screens without a notch.
    static let pillSize = CGSize(width: 160, height: 24)

    /// Every screen that should get a panel: the built-in display's notch, plus (optionally) a
    /// pill at the top of the primary screen (the one with the menu bar) when that's a
    /// different display. Without a notched built-in display, the pill is always shown.
    @MainActor
    static func detectAll(includeMainScreenPill: Bool = true) -> [NotchGeometry] {
        let screens = NSScreen.screens
        var result: [NotchGeometry] = []
        if let builtIn = screens.first(where: \.isBuiltIn), let geometry = notch(on: builtIn) {
            result.append(geometry)
        }
        if let primary = screens.first,
           includeMainScreenPill || result.isEmpty,
           !result.contains(where: { $0.displayID == primary.displayID }),
           let pill = pill(on: primary) {
            result.append(pill)
        }
        return result
    }

    @MainActor
    private static func notch(on screen: NSScreen) -> NotchGeometry? {
        guard screen.safeAreaInsets.top > 0,
              let displayID = screen.displayID,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea
        else { return nil }

        let frame = screen.frame
        let width = frame.width - left.width - right.width
        guard width > 0 else { return nil }

        return NotchGeometry(
            displayID: displayID,
            screenFrame: frame,
            notchSize: CGSize(width: width, height: screen.safeAreaInsets.top),
            centerX: frame.minX + left.width + width / 2,
            hasHardwareNotch: true
        )
    }

    @MainActor
    private static func pill(on screen: NSScreen) -> NotchGeometry? {
        guard let displayID = screen.displayID else { return nil }
        let frame = screen.frame
        return NotchGeometry(
            displayID: displayID,
            screenFrame: frame,
            notchSize: pillSize,
            centerX: frame.midX,
            hasHardwareNotch: false
        )
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var isBuiltIn: Bool {
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}
