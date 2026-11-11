import CoreGraphics

/// Size and corner radii of the notch shape in one mode.
struct NotchMetrics: Equatable {
    /// Size of the main body, not counting the outward flare at the top corners.
    var bodySize: CGSize
    /// Radius of the concave flare where the shape meets the top screen edge.
    var topRadius: CGFloat
    /// Radius of the rounded bottom corners.
    var bottomRadius: CGFloat

    /// Full drawn size, including the top flare on both sides.
    var shapeSize: CGSize {
        CGSize(width: bodySize.width + topRadius * 2, height: bodySize.height)
    }
}

enum NotchLayout {
    static let expandedWidth: CGFloat = 420
    /// Expanded height below the notch band (header row sits beside the notch).
    static let expandedContentHeight: CGFloat = 124

    /// Notch HUD: width, and the height of the row below the camera.
    static let hudDropWidth: CGFloat = 340
    static let hudDropHeight: CGFloat = 38
    static let aiAlertWidth: CGFloat = 390
    static let aiAlertDropHeight: CGFloat = 56

    /// Extra width on each side of a pill while its single-row pop-up is showing (a hardware
    /// notch's pop-up drops down instead; see `hudDropWidth`).
    static func hudWingWidth(for geometry: NotchGeometry, kind: HUDKind = .brightness) -> CGFloat {
        switch kind {
        case .volume, .brightness: return 80   // 16 squares
        case .battery, .device: return 96      // label + value
        case .capsLock, .inputSource, .timerDone: return 72
        case .aiAlert: return 150
        }
    }

    /// Wings beside the closed notch for a live activity (artwork + audio bars or countdown).
    static let liveWingWidth: CGFloat = 46
    /// Extra width on each side of the idle notch while the indicator dot is showing.
    /// (Nothing can be drawn inside the hardware notch: it has no pixels.)
    static let indicatorWingWidth: CGFloat = 16
    /// Extra height of the expanded panel while the shelf row is showing.
    static let shelfRowHeight: CGFloat = 68
    /// Height of the track progress row (time, bar, time) under now playing.
    static let progressRowHeight: CGFloat = 16

    /// Content height for the enabled panel sections (keep in sync with ExpandedPanelView).
    static func contentHeight(nowPlaying: Bool, audioControls: Bool) -> CGFloat {
        let topGap: CGFloat = 14, bottomPadding: CGFloat = 16, rowGap: CGFloat = 14
        var height = bottomPadding + 4
        if nowPlaying { height += topGap + 56 + 6 + progressRowHeight }
        if audioControls { height += (nowPlaying ? rowGap : topGap) + 20 }
        return height
    }

    /// Transparent margin around the shape so the expanded shadow isn't clipped.
    static let shadowPadding: CGFloat = 24

    static func metrics(
        for mode: NotchMode,
        geometry: NotchGeometry,
        indicator: Bool = false,
        shelf: Bool = false,
        contentHeight: CGFloat = expandedContentHeight,
        live: Bool = false
    ) -> NotchMetrics {
        let notch = geometry.notchSize
        switch mode {
        case .idle:
            let wings = live ? liveWingWidth * 2 : (indicator ? indicatorWingWidth * 2 : 0)
            let size = CGSize(width: notch.width + wings, height: notch.height)
            if geometry.hasHardwareNotch {
                return NotchMetrics(bodySize: size, topRadius: 6, bottomRadius: 9)
            }
            return NotchMetrics(bodySize: size, topRadius: 0, bottomRadius: notch.height / 2)

        case let .hud(kind, _):
            if geometry.hasHardwareNotch {
                // Drops down below the camera: a compact bar with the same row as the panel.
                // AI alerts have two lines (who, and what they need), so they're a bit bigger.
                if case .aiAlert = kind {
                    let size = CGSize(width: max(aiAlertWidth, notch.width + 48), height: notch.height + aiAlertDropHeight)
                    return NotchMetrics(bodySize: size, topRadius: 8, bottomRadius: 22)
                }
                let size = CGSize(width: max(hudDropWidth, notch.width + 48), height: notch.height + hudDropHeight)
                return NotchMetrics(bodySize: size, topRadius: 8, bottomRadius: 20)
            }
            let size = CGSize(width: notch.width + hudWingWidth(for: geometry, kind: kind) * 2, height: notch.height)
            return NotchMetrics(bodySize: size, topRadius: 6, bottomRadius: notch.height / 2.4)

        case .expanded:
            let size = CGSize(
                width: max(expandedWidth, notch.width + 200),
                height: notch.height + contentHeight + (shelf ? shelfRowHeight : 0)
            )
            return NotchMetrics(bodySize: size, topRadius: 12, bottomRadius: 30)
        }
    }

    /// The panel is sized once to fit the largest shape plus shadow, and never resized during
    /// animations; mouse pass-through is handled by hit-testing the shape instead.
    static func windowSize(for geometry: NotchGeometry) -> CGSize {
        let shapes = [
            metrics(for: .idle, geometry: geometry, indicator: true, live: true),
            metrics(for: .hud(kind: .battery(charging: true), level: 0), geometry: geometry),
            metrics(for: .hud(kind: .aiAlert(AIAlert(source: "", kind: .done, message: "")), level: 0), geometry: geometry),
            metrics(for: .hud(kind: .volume, level: 0), geometry: geometry),
            metrics(for: .expanded, geometry: geometry, shelf: true),
        ].map(\.shapeSize)
        let width = shapes.map(\.width).max() ?? 0
        let height = shapes.map(\.height).max() ?? 0
        return CGSize(width: width + shadowPadding * 2, height: height + shadowPadding)
    }
}
