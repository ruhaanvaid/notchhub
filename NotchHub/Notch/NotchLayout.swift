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

    /// Extra width on each side of the notch while a HUD is showing. A pill has no camera
    /// to work around, so its HUD can be more compact.
    static func hudWingWidth(for geometry: NotchGeometry, kind: HUDKind = .brightness) -> CGFloat {
        switch (geometry.hasHardwareNotch, kind) {
        case (true, .volume): return 104 // 16 small squares beside the camera, without a wide HUD
        case (true, .brightness): return 88
        case (false, .volume): return 80
        case (false, .brightness): return 64
        }
    }
    /// Extra width on each side of the idle notch while the indicator dot is showing.
    /// (Nothing can be drawn inside the hardware notch: it has no pixels.)
    static let indicatorWingWidth: CGFloat = 16
    /// Extra height of the expanded panel while the shelf row is showing.
    static let shelfRowHeight: CGFloat = 68
    /// Content height for the enabled panel sections (keep in sync with ExpandedPanelView).
    static func contentHeight(nowPlaying: Bool, audioControls: Bool) -> CGFloat {
        let topGap: CGFloat = 14, bottomPadding: CGFloat = 16, rowGap: CGFloat = 14
        var height = bottomPadding + 4
        if nowPlaying { height += topGap + 56 }
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
        contentHeight: CGFloat = expandedContentHeight
    ) -> NotchMetrics {
        let notch = geometry.notchSize
        switch mode {
        case .idle:
            let wings = indicator ? indicatorWingWidth * 2 : 0
            let size = CGSize(width: notch.width + wings, height: notch.height)
            if geometry.hasHardwareNotch {
                return NotchMetrics(bodySize: size, topRadius: 6, bottomRadius: 9)
            }
            return NotchMetrics(bodySize: size, topRadius: 0, bottomRadius: notch.height / 2)

        case let .hud(kind, _):
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
            metrics(for: .idle, geometry: geometry, indicator: true),
            metrics(for: .hud(kind: .volume, level: 0), geometry: geometry),
            metrics(for: .expanded, geometry: geometry, shelf: true),
        ].map(\.shapeSize)
        let width = shapes.map(\.width).max() ?? 0
        let height = shapes.map(\.height).max() ?? 0
        return CGSize(width: width + shadowPadding * 2, height: height + shadowPadding)
    }
}
