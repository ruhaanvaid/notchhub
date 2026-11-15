import SwiftUI

/// The panel's timer page, laid out like the Clock app's timer. Before it starts you get hours,
/// min and sec wheels between Cancel and Start. While it runs you get a countdown ring between
/// Cancel and Pause/Resume.
struct TimerPageView: View {
    let timer: TimerService
    /// Leaves the timer page (back to now playing).
    let close: () -> Void

    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int

    init(timer: TimerService, close: @escaping () -> Void) {
        self.timer = timer
        self.close = close
        let total = Int(timer.lastDuration)
        _hours = State(initialValue: min(total / 3600, 23))
        _minutes = State(initialValue: total / 60 % 60)
        _seconds = State(initialValue: total % 60)
    }

    private var pickedSeconds: Int { hours * 3600 + minutes * 60 + seconds }

    var body: some View {
        HStack(spacing: 0) {
            if timer.isActive {
                RoundButton(title: "Cancel", tint: NotchStyle.primary, background: Color.white.opacity(0.16)) {
                    timer.cancel()
                }
                Spacer(minLength: 8)
                CountdownRing(timer: timer)
                Spacer(minLength: 8)
                if timer.isPaused {
                    RoundButton(title: "Resume", tint: TimerColors.green, background: TimerColors.green.opacity(0.22), action: timer.resume)
                } else {
                    RoundButton(title: "Pause", tint: .orange, background: Color.orange.opacity(0.22), action: timer.pause)
                }
            } else {
                RoundButton(title: "Cancel", tint: NotchStyle.primary, background: Color.white.opacity(0.16), action: close)
                Spacer(minLength: 6)
                DurationWheels(hours: $hours, minutes: $minutes, seconds: $seconds)
                Spacer(minLength: 6)
                RoundButton(title: "Start", tint: TimerColors.green, background: TimerColors.green.opacity(0.22)) {
                    timer.start(seconds: TimeInterval(pickedSeconds))
                }
                .disabled(pickedSeconds == 0)
                .opacity(pickedSeconds == 0 ? 0.45 : 1)
            }
        }
        .frame(height: NotchLayout.timerWheelHeight)
        .animation(.easeOut(duration: 0.2), value: timer.isActive)
    }
}

enum TimerColors {
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
}

/// Round button in the Clock app's style: a tinted disc with a thin dark ring inside its edge.
private struct RoundButton: View {
    let title: String
    let tint: Color
    let background: Color
    let action: () -> Void

    init(title: String, tint: Color, background: Color, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.background = background
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(background)
                Circle().inset(by: 2.5).stroke(Color.black, lineWidth: 1.5)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 7)
            }
            .frame(width: 54, height: 54)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Hours / min / sec wheels with the selected row highlighted, as in the Clock app.
struct DurationWheels: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(height: NotchLayout.timerRowHeight + 2)
            HStack(spacing: 4) {
                WheelColumn(values: 0...23, value: $hours, unit: "hours")
                WheelColumn(values: 0...59, value: $minutes, unit: "min")
                WheelColumn(values: 0...59, value: $seconds, unit: "sec")
            }
        }
        .frame(width: 228)
    }
}

/// One wheel: numbers scroll and snap to the highlighted row; the unit label stays put beside
/// it. Scroll, swipe, or click a number to pick it.
private struct WheelColumn: View {
    let values: ClosedRange<Int>
    @Binding var value: Int
    let unit: String

    @State private var position: Int?

    init(values: ClosedRange<Int>, value: Binding<Int>, unit: String) {
        self.values = values
        _value = value
        self.unit = unit
        _position = State(initialValue: value.wrappedValue)
    }

    var body: some View {
        let rowHeight = NotchLayout.timerRowHeight
        let height = NotchLayout.timerWheelHeight
        HStack(spacing: 5) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { number in
                        WheelRow(number: number, rowHeight: rowHeight, wheelHeight: height)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) { position = number }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, (height - rowHeight) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .top)
            .frame(width: 30)

            Text(unit)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchStyle.primary)
                .frame(width: 38, alignment: .leading)
        }
        .frame(height: height)
        .onChange(of: position) { _, newValue in
            if let newValue { value = newValue }
        }
    }
}

/// One number on a wheel. Rows tilt away and fade toward the top and bottom, like a drum.
private struct WheelRow: View {
    let number: Int
    let rowHeight: CGFloat
    let wheelHeight: CGFloat

    var body: some View {
        let half = wheelHeight / 2
        Text(String(number))
            .font(Font.system(size: 18, weight: .regular).monospacedDigit())
            .foregroundStyle(NotchStyle.primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
            .visualEffect { content, proxy in Self.drum(content, proxy, half: half) }
    }

    nonisolated private static func drum(_ content: EmptyVisualEffect, _ proxy: GeometryProxy, half: CGFloat) -> some VisualEffect {
        // How far this row's center is from the wheel's center (positive = below).
        let wheelCenter: CGFloat = proxy.bounds(of: .scrollView)?.midY ?? proxy.size.height / 2
        let offset: CGFloat = proxy.size.height / 2 - wheelCenter
        let t: CGFloat = min(abs(offset) / half, 1)
        // Squash rows vertically as they turn away, like the face of a drum.
        let squash: CGFloat = cos(t * .pi / 2.6)
        return content
            .scaleEffect(CGSize(width: 1 - t * 0.1, height: squash), anchor: .trailing)
            .opacity(Double(1 - t * 0.8))
    }
}

/// Orange ring that empties as the timer runs, with the time left and when it ends inside.
private struct CountdownRing: View {
    let timer: TimerService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timer.remaining(at: context.date)
            let progress = timer.duration > 0 ? remaining / timer.duration : 0
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 2) {
                    Text(TimerService.format(remaining: remaining))
                        .font(.system(size: remaining >= 3600 ? 19 : 24, weight: .light).monospacedDigit())
                        .foregroundStyle(NotchStyle.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill").font(.system(size: 8))
                        Text(endText(remaining: remaining, now: context.date))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                    }
                    .foregroundStyle(timer.isPaused ? NotchStyle.tertiary : NotchStyle.secondary)
                }
            }
            .frame(width: NotchLayout.timerWheelHeight - 4, height: NotchLayout.timerWheelHeight - 4)
        }
    }

    private func endText(remaining: TimeInterval, now: Date) -> String {
        now.addingTimeInterval(remaining).formatted(date: .omitted, time: .shortened)
    }
}
