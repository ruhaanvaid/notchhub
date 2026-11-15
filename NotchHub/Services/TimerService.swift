import AppKit
import Observation

/// A countdown set with the hours / min / sec wheels in the panel. While it runs, the remaining
/// time sits in the closed notch's wings; when it ends, NotchHub plays a sound and shows a
/// pop-up. It can be paused and resumed, like the Clock app's timer.
@Observable
@MainActor
final class TimerService {
    /// When the running timer ends; nil while paused or stopped.
    private(set) var endDate: Date?
    /// Time left while paused; nil while running or stopped.
    private(set) var pausedRemaining: TimeInterval?
    /// Length of the current timer, for the progress ring.
    private(set) var duration: TimeInterval = 0

    /// Last length started, so the wheels open where you left them. Defaults to 5 minutes.
    var lastDuration: TimeInterval {
        didSet { UserDefaults.standard.set(lastDuration, forKey: Self.lastDurationKey) }
    }

    /// Called when the timer reaches zero.
    @ObservationIgnored var onFinished: (() -> Void)?
    @ObservationIgnored private var timer: Timer?
    private static let lastDurationKey = "timerLastDuration"

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.lastDurationKey)
        lastDuration = saved > 0 ? saved : 5 * 60
    }

    /// Running or paused.
    var isActive: Bool { endDate != nil || pausedRemaining != nil }
    var isPaused: Bool { pausedRemaining != nil }

    /// Time left at `date`.
    func remaining(at date: Date = Date()) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return 0
    }

    func start(seconds: TimeInterval) {
        guard seconds >= 1 else { return }
        cancel()
        duration = seconds
        lastDuration = seconds
        schedule(seconds)
    }

    func pause() {
        guard let endDate else { return }
        timer?.invalidate()
        timer = nil
        pausedRemaining = max(1, endDate.timeIntervalSinceNow)
        self.endDate = nil
    }

    func resume() {
        guard let pausedRemaining else { return }
        self.pausedRemaining = nil
        schedule(pausedRemaining)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        pausedRemaining = nil
    }

    private func schedule(_ seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        endDate = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func finish() {
        timer = nil
        endDate = nil
        pausedRemaining = nil
        NSSound(named: "Glass")?.play()
        onFinished?()
    }

    /// "4:59", "24:00", "1:05:00".
    static func format(remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        let hours = seconds / 3600, minutes = seconds / 60 % 60, secs = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
