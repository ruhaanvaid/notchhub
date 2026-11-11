import AppKit
import Observation

/// What a pop-up from the notch is showing.
enum HUDKind: Equatable {
    case volume
    case brightness
    /// Plugged in (`charging`) or a low-battery warning; level is the charge, 0...1.
    case battery(charging: Bool)
    /// Headphones or a speaker connected.
    case device(name: String, symbol: String)
    case capsLock(on: Bool)
    /// Keyboard input source changed (e.g. "ABC", "French").
    case inputSource(name: String)
    case timerDone

    /// Volume and brightness follow the HUD-duration setting; notices stay a little longer.
    @MainActor var duration: Double {
        switch self {
        case .volume, .brightness: return AppSettings.shared.hudDuration
        case .capsLock, .inputSource: return 1.5
        case .battery, .device: return 2.5
        case .timerDone: return 4
        }
    }
}

/// Small "live activity" shown in wings beside the closed notch.
struct LiveActivity: Equatable {
    /// Album art or a site icon (left wing); nil shows a music note.
    var artwork: NSImage?
    var tint: NSColor?
    var isPlaying: Bool
    /// When a timer is running, its end; the countdown replaces the audio bars.
    var timerEnd: Date?
    /// Whether anything is playing (the artwork side is shown).
    var showsMedia: Bool
}

enum NotchMode: Equatable {
    case idle
    case hud(kind: HUDKind, level: Double)
    case expanded

    var isExpanded: Bool { self == .expanded }

    var isHUD: Bool {
        if case .hud = self { return true }
        return false
    }
}

/// Single source of truth for the notch UI.
@Observable
@MainActor
final class NotchState {
    private(set) var mode: NotchMode = .idle {
        didSet {
            if mode != oldValue { notifyShapeChange() }
        }
    }

    /// Shows a small dot beside the idle notch (keep-awake is on).
    var indicatorVisible = false {
        didSet {
            if indicatorVisible != oldValue { notifyShapeChange() }
        }
    }

    /// The shelf has files in it.
    var shelfHasItems = false {
        didSet {
            if shelfHasItems != oldValue { notifyShapeChange() }
        }
    }

    /// A file drag is hovering over the panel.
    var isDropTargeted = false {
        didSet {
            if isDropTargeted != oldValue { notifyShapeChange() }
        }
    }

    /// The expanded panel shows the shelf row (it has items, or a drop is incoming).
    var showsShelf: Bool { shelfHasItems || isDropTargeted }

    /// Height of the expanded panel below the notch band, for the sections that are enabled.
    var expandedContentHeight: CGFloat = NotchLayout.expandedContentHeight {
        didSet {
            if expandedContentHeight != oldValue { notifyShapeChange() }
        }
    }

    var geometry: NotchGeometry?

    /// Now playing and/or timer in the closed notch's wings; nil hides them.
    var live: LiveActivity? {
        didSet {
            if (live == nil) != (oldValue == nil) { notifyShapeChange() }
        }
    }


    @ObservationIgnored private var shapeObservers: [@MainActor (NotchMode) -> Void] = []
    @ObservationIgnored private var hudHideTask: Task<Void, Never>?

    /// Shape metrics for the current mode, or nil when there is no screen to draw on.
    var metrics: NotchMetrics? {
        geometry.map {
            NotchLayout.metrics(
                for: mode, geometry: $0, indicator: indicatorVisible, shelf: showsShelf,
                contentHeight: expandedContentHeight, live: live != nil
            )
        }
    }

    /// Called after every change to the mode or the shape's size.
    func observeShapeChanges(_ observer: @escaping @MainActor (NotchMode) -> Void) {
        shapeObservers.append(observer)
    }

    func expand() {
        hudHideTask?.cancel()
        mode = .expanded
    }

    func collapse() {
        hudHideTask?.cancel()
        mode = .idle
    }

    /// Shows the HUD and restarts its hide timer. Ignored while the panel is expanded.
    func showHUD(_ kind: HUDKind, level: Double) {
        guard !mode.isExpanded else { return }
        mode = .hud(kind: kind, level: min(max(level, 0), 1))

        hudHideTask?.cancel()
        let hudDuration = Duration.milliseconds(Int(kind.duration * 1000))
        hudHideTask = Task { [weak self] in
            try? await Task.sleep(for: hudDuration)
            guard !Task.isCancelled, let self, self.mode.isHUD else { return }
            self.mode = .idle
        }
    }

    private func notifyShapeChange() {
        let mode = self.mode
        shapeObservers.forEach { $0(mode) }
    }
}
