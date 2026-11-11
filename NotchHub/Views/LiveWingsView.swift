import SwiftUI

/// The closed notch's "live activity": artwork in the left wing; animated audio bars (or a
/// timer countdown) in the right wing; nothing under the camera housing.
struct LiveWingsView: View {
    let live: LiveActivity
    /// Width of the camera housing, or of the pill body.
    let notchWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let wing = NotchLayout.liveWingWidth
        HStack(spacing: 0) {
            leading.frame(width: wing)
            Color.clear.frame(width: notchWidth)
            trailing.frame(width: wing)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var leading: some View {
        if live.showsMedia {
            let side = min(22, height - 10)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(NotchStyle.fill)
                if let artwork = live.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .transition(.scale.combined(with: .opacity))
        } else if live.timerEnd != nil {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let end = live.timerEnd {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(TimerService.format(remaining: end.timeIntervalSince(context.date)))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText(countsDown: true))
            }
        } else if live.showsMedia {
            AudioBars(isPlaying: live.isPlaying, tint: live.tint.map(Color.init(nsColor:)) ?? NotchStyle.primary)
                .frame(width: 16, height: 12)
        }
    }
}

/// Four bars that bounce gently while playing and rest when paused.
struct AudioBars: View {
    let isPlaying: Bool
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let speed = [5.1, 6.7, 4.3, 5.9][index]
                    let phase = [0.0, 1.3, 2.1, 0.7][index]
                    let wave = isPlaying ? (sin(t * speed + phase) + 1) / 2 : 0
                    Capsule()
                        .fill(tint)
                        .frame(width: 2.5, height: 3 + 9 * wave)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
