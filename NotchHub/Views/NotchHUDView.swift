import SwiftUI

/// Pop-up from the notch: one row (icon, content, value). On a hardware notch the shape drops
/// down below the camera housing and the row sits there; on a pill (no camera) the row fills
/// the pill itself.
///
/// Volume and brightness use Apple's 16-step scale: 16 squares and a step count ("11", or
/// "10¼" after a Shift+Option fine step).
struct NotchHUDView: View {
    let kind: HUDKind
    let level: Double
    let height: CGFloat
    let hasCamera: Bool

    var body: some View {
        if hasCamera {
            VStack(spacing: 0) {
                Color.clear.frame(height: height)
                row
                    .padding(.horizontal, 18)
                    .frame(height: rowHeight)
                Spacer(minLength: 0)
            }
        } else {
            row
                .padding(.horizontal, 14)
                .frame(height: height)
        }
    }

    @ViewBuilder
    private var row: some View {
        switch kind {
        case .volume, .brightness:
            HStack(spacing: 12) {
                icon(symbolName)
                SegmentedLevel(level: level, minSpacing: 3).frame(height: 12)
                valueText(VolumeSteps.format(level)).frame(width: 28, alignment: .trailing)
            }

        case let .battery(charging):
            let color: Color = charging ? .green : (level <= 0.1 ? .red : (level <= 0.2 ? .orange : NotchStyle.primary))
            HStack(spacing: 10) {
                icon(Self.batterySymbol(level: level, charging: charging), color: color)
                label(charging ? "Charging" : "Low Battery")
                LevelBar(level: level, color: color).frame(height: 6)
                valueText("\(Int((level * 100).rounded()))%").frame(width: 38, alignment: .trailing)
            }

        case let .device(name, symbol):
            HStack(spacing: 10) {
                icon(symbol)
                label(name).frame(maxWidth: .infinity, alignment: .leading)
                valueText("Connected")
            }

        case let .capsLock(on):
            HStack(spacing: 10) {
                icon(on ? "capslock.fill" : "capslock")
                label("Caps Lock").frame(maxWidth: .infinity, alignment: .leading)
                valueText(on ? "On" : "Off")
            }

        case let .inputSource(name):
            HStack(spacing: 10) {
                icon("globe")
                label(name).frame(maxWidth: .infinity, alignment: .leading)
                valueText("Keyboard")
            }

        case .timerDone:
            HStack(spacing: 10) {
                icon("timer", color: .orange)
                label("Timer done").frame(maxWidth: .infinity, alignment: .leading)
                valueText("00:00")
            }

        case let .aiAlert(alert):
            AIAlertRow(alert: alert, compact: !hasCamera)
        }
    }

    private var rowHeight: CGFloat {
        if case .aiAlert = kind { return NotchLayout.aiAlertDropHeight - 8 }
        return NotchLayout.hudDropHeight - 6
    }

    private func icon(_ name: String, color: Color = NotchStyle.primary) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 24)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(NotchStyle.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(NotchStyle.secondary)
            .contentTransition(.numericText(value: level))
            .lineLimit(1)
            .fixedSize()
    }

    private var symbolName: String {
        if kind == .brightness { return level < 0.5 ? "sun.min.fill" : "sun.max.fill" }
        switch level {
        case ..<0.001: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    static func batterySymbol(level: Double, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case ..<0.13: return "battery.0"
        case ..<0.38: return "battery.25"
        case ..<0.63: return "battery.50"
        case ..<0.88: return "battery.75"
        default: return "battery.100"
        }
    }
}

/// Apple's 16-step scale for volume and brightness.
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
    var color: Color = NotchStyle.primary

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(NotchStyle.fillStrong)
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.height, proxy.size.width * min(max(level, 0), 1)))
                    .opacity(level > 0.001 ? 1 : 0)
            }
        }
    }
}

/// "Claude Code · notch" / "Needs your permission to use Bash", with the tool's icon and a
/// status badge. Clicking the pop-up brings the tool's app forward.
struct AIAlertRow: View {
    let alert: AIAlert
    /// Single line, for the short pill on screens without a notch.
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let image = AIAlertService.icon(for: alert) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NotchStyle.primary)
                }
            }
            .frame(width: compact ? 18 : 30, height: compact ? 18 : 30)

            if compact {
                Text("\(alert.source): \(alert.message)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotchStyle.secondary)
                        .lineLimit(1)
                    Text(alert.message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotchStyle.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(badge)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color, in: Capsule())
                .fixedSize()
        }
        .contentShape(Rectangle())
    }

    private var badge: String {
        switch alert.kind {
        case .needsInput: return "Needs you"
        case .done: return "Done"
        case .error: return "Error"
        case .info: return "Update"
        }
    }

    private var color: Color {
        switch alert.kind {
        case .needsInput: return .orange
        case .done: return .green
        case .error: return .red
        case .info: return Color(white: 0.8)
        }
    }
}
