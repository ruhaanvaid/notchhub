import SwiftUI

/// Fills the whole panel; draws the notch shape pinned to the top center.
struct NotchRootView: View {
    let state: NotchState
    let context: PanelContext

    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.8)

    var body: some View {
        ZStack(alignment: .top) {
            if let metrics = state.metrics, let geometry = state.geometry {
                notch(metrics: metrics, geometry: geometry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
        .animation(Self.spring, value: state.mode)
        .animation(Self.spring, value: state.indicatorVisible)
        .animation(Self.spring, value: state.live != nil)
        .animation(Self.spring, value: state.showsShelf)
        .animation(Self.spring, value: state.geometry)
    }

    private func notch(metrics: NotchMetrics, geometry: NotchGeometry) -> some View {
        let shape = NotchShape(topRadius: metrics.topRadius, bottomRadius: metrics.bottomRadius)
        let expanded = state.mode.isExpanded

        return ZStack(alignment: .top) {
            shape.fill(Color.black)

            switch state.mode {
            case .idle:
                if let live = state.live {
                    LiveWingsView(live: live, notchWidth: geometry.notchSize.width, height: geometry.notchSize.height)
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                } else if state.indicatorVisible {
                    IndicatorDot(notchSize: geometry.notchSize)
                        .transition(.opacity)
                }

            case let .hud(kind, level):
                NotchHUDView(
                    kind: kind,
                    level: level,
                    height: geometry.notchSize.height,
                    hasCamera: geometry.hasHardwareNotch
                )
                .contentShape(Rectangle())
                .onTapGesture { state.hudTapped() }
                .transition(.opacity.animation(.easeOut(duration: 0.15)))

            case .expanded:
                ExpandedPanelView(state: state, context: context, geometry: geometry)
                    .padding(.horizontal, metrics.topRadius + 18)
                    .padding(.bottom, 16)
                    .transition(
                        .opacity
                            .combined(with: .scale(scale: 0.92, anchor: .top))
                            .animation(Self.spring.delay(0.05))
                    )
            }
        }
        .frame(width: metrics.shapeSize.width, height: metrics.shapeSize.height)
        .clipShape(shape)
        .shadow(color: .black.opacity(expanded ? 0.45 : 0), radius: 14, y: 4)
    }
}

/// Keep-awake indicator in the right wing beside the idle notch.
private struct IndicatorDot: View {
    let notchSize: CGSize

    var body: some View {
        let wing = NotchLayout.indicatorWingWidth
        HStack(spacing: 0) {
            Color.clear.frame(width: wing + notchSize.width)
            Circle()
                .fill(Color.cyan)
                .frame(width: 6, height: 6)
                .frame(width: wing)
        }
        .frame(height: notchSize.height)
    }
}
