import AppKit
import Observation

/// Checks GitHub for a newer NotchHub release. It only tells the user; nothing is downloaded
/// or installed automatically. Automatic checks run at most once a day and can be turned off
/// in Settings. The request carries no personal data: it's an anonymous call to GitHub's
/// public releases API.
@Observable
@MainActor
final class UpdateService {
    struct Release: Equatable, Sendable {
        let version: String
        /// The release page, with notes and the download.
        let pageURL: URL
    }

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case failed(String)
    }

    private(set) var status: Status = .idle

    var availableUpdate: Release? {
        if case let .available(release) = status { return release }
        return nil
    }

    /// Called when a check finds a newer release (drives the menu-bar dot).
    @ObservationIgnored var onStatusChange: ((Status) -> Void)?

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static let repository = "ruhaanvaid/notchhub"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/\(repository)/releases/latest")!

    private static let lastCheckKey = "lastUpdateCheck"
    private let checkInterval: TimeInterval = 24 * 60 * 60

    @ObservationIgnored private var timer: Timer?

    func start() {
        // Look shortly after launch, then hourly see whether a day has passed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in self?.checkIfDue() }
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Automatic check: only when enabled and a day has passed since the last one.
    func checkIfDue() {
        guard AppSettings.shared.checkForUpdates else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= checkInterval else { return }
        Task { await check() }
    }

    /// Checks now, regardless of schedule. Returns the resulting status.
    @discardableResult
    func check() async -> Status {
        guard status != .checking else { return status }
        setStatus(.checking)

        var request = URLRequest(url: Self.apiURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotchHub/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        let result: Status
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 {
                result = .upToDate // No releases published yet.
            } else if code == 200, let release = Self.parse(data) {
                result = Self.isNewer(release.version, than: Self.currentVersion) ? .available(release) : .upToDate
            } else {
                result = .failed("GitHub returned an unexpected response (\(code)).")
            }
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
        } catch {
            result = .failed(error.localizedDescription)
        }
        setStatus(result)
        return result
    }

    func openReleasePage() {
        NSWorkspace.shared.open(availableUpdate?.pageURL ?? Self.releasesPage)
    }

    private func setStatus(_ newStatus: Status) {
        status = newStatus
        onStatusChange?(newStatus)
    }

    // MARK: - Helpers (pure, unit-testable)

    /// Reads `tag_name` ("v0.3.0") and `html_url` from GitHub's latest-release JSON.
    nonisolated static func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else { return nil }
        let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        return Release(version: version, pageURL: page)
    }

    /// Numeric dotted comparison: "0.10.0" is newer than "0.9.2"; "1.0" equals "1.0.0".
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ version: String) -> [Int] {
            version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
