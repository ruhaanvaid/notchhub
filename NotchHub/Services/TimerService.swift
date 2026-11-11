import AppKit
import Observation

/// A simple countdown (5, 10 or 25 minutes from the panel). While it runs, the remaining time
/// sits in the closed notch's wings; when it ends, NotchHub plays a sound and shows a pop-up.
@Observable
@MainActor
final class TimerService {
    static let presets = [5, 10, 25]

    private(set) var endDate: Date?
    /// Called when the timer reaches zero.
    @ObservationIgnored var onFinished: (() -> Void)?
    @ObservationIgnored private var timer: Timer?

    var isRunning: Bool { endDate != nil }

    func start(minutes: Int) {
        cancel()
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endDate = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        endDate = nil
    }

    private func finish() {
        timer = nil
        endDate = nil
        NSSound(named: "Glass")?.play()
        onFinished?()
    }

    /// "4:59", "24:00".
    static func format(remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
