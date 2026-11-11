import SwiftUI

/// Volume/brightness HUD. Around a hardware notch: icon and value in the left wing, meter in
/// the right wing, camera housing between them. On a pill (no camera) it's one continuous row.
///
/// Volume uses Apple's 16-step scale: 16 segments and a step count ("11", or "10¼" after a
/// Shift+Option fine step). Brightness uses a bar and a percentage.
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
                        if kind == .volume { Spacer(minLength: 0) }
                        value
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, kind == .volume ? 12 : 0)
                    .frame(width: wingWidth, alignment: .leading)
                    // Nothing can be drawn under the camera housing.
                    Color.clear.frame(width: notchWidth)
                    meter
                        .padding(.leading, kind == .volume ? 6 : 8)
                        .padding(.trailing, kind == .volume ? 14 : 16)
                        .frame(width: wingWidth)
                }
            } else {
                HStack(spacing: 10) {
                    icon
                    meter
                    value.frame(width: 30, alignment: .trailing)
                }
                .padding(.horizontal, 14)
            }
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var meter: some View {
        switch kind {
        case .volume:
            SegmentedLevel(level: level).frame(height: 8)
        case .brightness:
            LevelBar(level: level).frame(height: 5)
        }
    }

    /// "11" (steps out of 16) for volume, "62" (percent) for brightness.
    private var value: some View {
        let text = kind == .volume ? VolumeSteps.format(level) : "\(Int((level * 100).rounded()))"
        return Text(text)
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

/// Apple's 16-step volume scale.
enum VolumeSteps {
    static let count = 16

    /// "0"–"16", with ¼ ½ ¾ for Shift+Option fine steps (e.g. "10¼").
    static func format(_ level: Double) -> String {
        let quarters = Int((min(max(level, 0), 1) * Double(count) * 4).rounded())
        let whole = quarters / 4
        let fraction = ["", "¼", "½", "¾"][quarters % 4]
        return whole == 0 && !fraction.isEmpty ? fraction : "\(whole)\(fraction)"
    }
}

/// 16 square segments, like the native volume HUD; a fine step fills part of a segment.
/// Squares are as big as the height allows (or the width, if that's tighter) and spread out
/// evenly to fill the width.
struct SegmentedLevel: View {
    let level: Double
    var minSpacing: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let count = CGFloat(VolumeSteps.count)
            let size = max(1, min(proxy.size.height, (proxy.size.width - minSpacing * (count - 1)) / count))
            let spacing = max(minSpacing, (proxy.size.width - size * count) / (count - 1))
            let filled = min(max(level, 0), 1) * Double(VolumeSteps.count)
            HStack(spacing: spacing) {
                ForEach(0..<VolumeSteps.count, id: \.self) { index in
                    let fraction = min(max(filled - Double(index), 0), 1)
                    let corner = max(1, size * 0.22)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(NotchStyle.fillStrong)
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(NotchStyle.primary)
                            .frame(width: size * fraction)
                    }
                    .frame(width: size, height: size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .animation(.easeOut(duration: 0.12), value: level)
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
