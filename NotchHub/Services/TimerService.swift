import AppKit
import Observation

/// A countdown set with the hours / min / sec wheels in the panel. While it runs, the remaining
/// time sits in the closed notch's wings. When it ends an alarm rings, with a pop-up from the
/// notch, until it's stopped (or for two minutes). It can be paused and resumed, like the
/// Clock app's timer.
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

    /// The alarm is ringing (the timer reached zero and nobody has stopped it yet).
    private(set) var isRinging = false

    /// Called when the timer reaches zero and the alarm starts.
    @ObservationIgnored var onFinished: (() -> Void)?
    /// Called when the alarm stops: Stop, Repeat, a new timer, or after two minutes.
    @ObservationIgnored var onAlarmStopped: (() -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var alarm: AlarmSound?
    @ObservationIgnored private var alarmTimeout: Timer?
    /// The alarm gives up after this long.
    static let alarmLimit: TimeInterval = 120
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
        stopAlarm()
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

    /// Silences the alarm and takes its pop-up down.
    func stopAlarm() {
        guard isRinging else { return }
        isRinging = false
        alarm?.stop()
        alarm = nil
        alarmTimeout?.invalidate()
        alarmTimeout = nil
        onAlarmStopped?()
    }

    /// Stops the alarm and runs the same timer again.
    func repeatLast() {
        start(seconds: duration > 0 ? duration : lastDuration)
    }

    private func finish() {
        timer = nil
        endDate = nil
        pausedRemaining = nil
        isRinging = true
        let alarm = AlarmSound(named: AppSettings.shared.timerSound)
        alarm.start()
        self.alarm = alarm
        let timeout = Timer(timeInterval: Self.alarmLimit, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopAlarm() }
        }
        RunLoop.main.add(timeout, forMode: .common)
        alarmTimeout = timeout
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

/// Rings one of macOS's alert sounds over and over, with a short pause between rings, until
/// stopped.
@MainActor
final class AlarmSound {
    /// Sounds offered in Settings: the alert sounds in /System/Library/Sounds.
    static var choices: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        let names = files.filter { $0.hasSuffix(".aiff") }.map { String($0.dropLast(5)) }.sorted()
        return names.isEmpty ? ["Glass"] : names
    }

    private let name: String
    private var sound: NSSound?
    private var ringTimer: Timer?

    init(named name: String) {
        self.name = name
    }

    func start() {
        ring()
        let gap = max(1.0, (NSSound(named: name)?.duration ?? 1) + 0.3)
        let timer = Timer(timeInterval: gap, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.ring() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ringTimer = timer
    }

    func stop() {
        ringTimer?.invalidate()
        ringTimer = nil
        sound?.stop()
        sound = nil
    }

    /// Plays one ring, for choosing a sound in Settings.
    static func preview(_ name: String) {
        (NSSound(named: name)?.copy() as? NSSound)?.play()
    }

    private func ring() {
        sound?.stop()
        // A copy, so a ring can start while the sound is still playing elsewhere.
        sound = (NSSound(named: name) ?? NSSound(named: "Glass"))?.copy() as? NSSound
        sound?.play()
    }
}
