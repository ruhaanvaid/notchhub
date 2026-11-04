import SwiftUI

/// Volume/brightness HUD. Around a hardware notch: icon in the left wing, level bar in the
/// right wing, camera housing between them. On a pill (no camera) it's one continuous row.
struct NotchHUDView: View {
    let kind: HUDKind
    let level: Double
    let notchWidth: CGFloat
    let wingWidth: CGFloat
    let height: CGFloat
    let hasCamera: Bool

    var body: some View {
        Group {
            if hasCamera {
                HStack(spacing: 0) {
                    HStack(spacing: 7) {
                        icon
                        percentage
                    }
                    .padding(.leading, 16)
                    .frame(width: wingWidth, alignment: .leading)
                    // Nothing can be drawn under the camera housing.
                    Color.clear.frame(width: notchWidth)
                    LevelBar(level: level)
                        .frame(height: 5)
                        .padding(.leading, 8)
                        .padding(.trailing, 16)
                        .frame(width: wingWidth)
                }
            } else {
                HStack(spacing: 10) {
                    icon
                    LevelBar(level: level).frame(height: 5)
                    percentage.frame(width: 26, alignment: .trailing)
                }
                .padding(.horizontal, 14)
            }
        }
        .frame(height: height)
    }

    /// Whole-number percentage, e.g. "62".
    private var percentage: some View {
        Text("\(Int((level * 100).rounded()))")
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(NotchStyle.secondary)
            .contentTransition(.numericText(value: level))
            .lineLimit(1)
            .fixedSize()
    }

    private var icon: some View {
        Image(systemName: symbolName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(NotchStyle.primary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 20)
    }

    private var symbolName: String {
        switch kind {
        case .volume:
            switch level {
            case ..<0.001: return "speaker.slash.fill"
            case ..<0.34: return "speaker.wave.1.fill"
            case ..<0.67: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        case .brightness:
            return level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }
}

struct LevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(NotchStyle.fillStrong)
                Capsule()
                    .fill(NotchStyle.primary)
                    .frame(width: max(proxy.size.height, proxy.size.width * min(max(level, 0), 1)))
                    .opacity(level > 0.001 ? 1 : 0)
            }
        }
    }
}
