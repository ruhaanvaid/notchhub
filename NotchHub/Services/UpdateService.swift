import AppKit
import Observation
import OSLog
import Security

private let log = Logger(subsystem: "com.notchhub.app", category: "updates")

/// Checks GitHub for a newer NotchHub release and, when asked, installs it in place: it
/// downloads the release zip, verifies it's signed with the same certificate as the running
/// app, replaces the app where it lives (normally /Applications), and relaunches it.
/// Settings, the shelf and permissions carry over because the identity doesn't change.
///
/// Automatic checks run at most once a day and can be turned off in Settings. Nothing is
/// installed without the user choosing Install. The check is an anonymous request to
/// GitHub's public releases API.
@Observable
@MainActor
final class UpdateService {
    struct Release: Equatable, Sendable {
        let version: String
        /// The release page, with notes and the download.
        let pageURL: URL
        /// The NotchHub-x.y.z.zip asset, if the release has one.
        let downloadURL: URL?
    }

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case installing(Release, String)
        case failed(String)
    }

    enum InstallError: LocalizedError {
        case noDownload
        case notWritable(String)
        case badArchive
        case wrongApp
        case notNewer
        case signatureMismatch
        case ownSignatureUnavailable

        var errorDescription: String? {
            switch self {
            case .noDownload: return "This release has no download for NotchHub."
            case let .notWritable(path): return "NotchHub can't replace itself at \(path). Move it to your Applications folder, or install the update by hand."
            case .badArchive: return "The download didn't contain NotchHub.app."
            case .wrongApp: return "The download isn't NotchHub."
            case .notNewer: return "The download isn't newer than this version."
            case .signatureMismatch: return "The download isn't signed by the same developer as this copy, so it wasn't installed."
            case .ownSignatureUnavailable: return "This copy of NotchHub isn't signed in a way that allows automatic updates. Install the update by hand."
            }
        }
    }

    private(set) var status: Status = .idle

    var availableUpdate: Release? {
        switch status {
        case let .available(release), let .installing(release, _): return release
        default: return nil
        }
    }

    var isInstalling: Bool {
        if case .installing = status { return true }
        return false
    }

    /// Called on every status change (drives the menu-bar dot).
    @ObservationIgnored var onStatusChange: ((Status) -> Void)?

    nonisolated static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static let repository = "ruhaanvaid/notchhub"
    static let releasesPage = URL(string: "https://github.com/\(repository)/releases/latest")!
    private static var feedURL: URL {
        #if DEBUG
        // Test hook: point the updater at a local feed.
        if let override = ProcessInfo.processInfo.environment["NOTCHHUB_UPDATE_FEED"],
           let url = URL(string: override) { return url }
        #endif
        return URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    private static let lastCheckKey = "lastUpdateCheck"
    private let checkInterval: TimeInterval = 24 * 60 * 60

    @ObservationIgnored private var timer: Timer?

    func start() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["NOTCHHUB_INSTALL_UPDATE_ON_LAUNCH"] == "1" {
            Task {
                if case .available = await check() { await install() }
            }
            return
        }
        #endif
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
        guard AppSettings.shared.checkForUpdates, !isInstalling else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= checkInterval else { return }
        Task { await check() }
    }

    // MARK: - Checking

    /// Checks now, regardless of schedule. Returns the resulting status.
    @discardableResult
    func check() async -> Status {
        guard status != .checking, !isInstalling else { return status }
        setStatus(.checking)

        var request = URLRequest(url: Self.feedURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotchHub/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        let result: Status
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 200 // file:// feeds in tests
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

    // MARK: - Installing

    /// Downloads, verifies and installs the available update, then relaunches. On success the
    /// app quits and a helper swaps the bundle and opens the new version. Returns an error
    /// message on failure (the current copy is left untouched).
    @discardableResult
    func install() async -> String? {
        guard let release = availableUpdate, !isInstalling else { return nil }
        do {
            guard let downloadURL = release.downloadURL else { throw InstallError.noDownload }
            let appURL = Bundle.main.bundleURL
            let parent = appURL.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: parent.path),
                  FileManager.default.isWritableFile(atPath: appURL.path)
            else { throw InstallError.notWritable(appURL.path) }

            setStatus(.installing(release, "Downloading…"))
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent("NotchHubUpdate-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let (downloaded, _) = try await URLSession.shared.download(from: downloadURL)
            let zip = staging.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: downloaded, to: zip)

            setStatus(.installing(release, "Verifying…"))
            let newApp = try await Self.unpackAndVerify(zip: zip, in: staging, expectedVersion: release.version)

            setStatus(.installing(release, "Installing…"))
            try Self.launchSwapHelper(newApp: newApp, replacing: appURL, staging: staging)
            log.info("installing \(release.version, privacy: .public) over \(appURL.path, privacy: .public); relaunching")
            NSApp.terminate(nil)
            return nil
        } catch {
            let message = error.localizedDescription
            log.error("update install failed: \(message, privacy: .public)")
            setStatus(.available(release))
            return message
        }
    }

    /// Unzips the download and checks it's NotchHub, newer, and signed by the same identity
    /// as this running copy (its designated requirement).
    private nonisolated static func unpackAndVerify(zip: URL, in staging: URL, expectedVersion: String) async throws -> URL {
        let unpacked = staging.appendingPathComponent("unpacked", isDirectory: true)
        try await run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
        let newApp = unpacked.appendingPathComponent("NotchHub.app")
        guard let bundle = Bundle(url: newApp), bundle.executableURL != nil else { throw InstallError.badArchive }
        guard bundle.bundleIdentifier == Bundle.main.bundleIdentifier else { throw InstallError.wrongApp }
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard isNewer(version, than: currentVersion) else { throw InstallError.notNewer }
        try verifySameSigner(newApp)
        // Downloads made by NotchHub aren't quarantined, but make sure Gatekeeper won't block
        // the relaunch if something added the attribute.
        try? await run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])
        return newApp
    }

    /// The new app must satisfy the running app's own designated requirement, i.e. be signed
    /// with the same certificate. An ad-hoc signed copy (requirement pinned to its own hash)
    /// can never accept an update this way, which is the safe failure.
    private nonisolated static func verifySameSigner(_ newApp: URL) throws {
        var selfCode: SecCode?
        var selfStatic: SecStaticCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
              SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic,
              SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess, let requirement
        else { throw InstallError.ownSignatureUnavailable }

        var description: CFString?
        SecRequirementCopyString(requirement, [], &description)
        if let description, (description as String).contains("cdhash") {
            throw InstallError.ownSignatureUnavailable
        }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(newApp as CFURL, [], &staticCode) == errSecSuccess, let staticCode
        else { throw InstallError.signatureMismatch }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
        else { throw InstallError.signatureMismatch }
    }

    /// Starts a small shell helper that waits for NotchHub to quit, swaps the bundles (rolling
    /// back if the move fails), opens the new version and cleans up.
    private static func launchSwapHelper(newApp: URL, replacing appURL: URL, staging: URL) throws {
        let script = staging.appendingPathComponent("swap.sh")
        try """
            #!/bin/sh
            PID="$1"; OLD="$2"; NEW="$3"; STAGING="$4"
            while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
            BACKUP="$OLD.previous-$$"
            if mv "$OLD" "$BACKUP"; then
              if mv "$NEW" "$OLD"; then rm -rf "$BACKUP"; else mv "$BACKUP" "$OLD"; fi
            fi
            open "$OLD"
            rm -rf "$STAGING"
            """.write(to: script, atomically: true, encoding: .utf8)

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            script.path, String(ProcessInfo.processInfo.processIdentifier),
            appURL.path, newApp.path, staging.path,
        ]
        try helper.run()
    }

    private nonisolated static func run(_ tool: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: InstallError.badArchive)
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    private func setStatus(_ newStatus: Status) {
        status = newStatus
        onStatusChange?(newStatus)
    }

    // MARK: - Helpers (pure, unit-testable)

    /// Reads `tag_name` ("v0.3.0"), `html_url` and the NotchHub zip asset from GitHub's
    /// latest-release JSON.
    nonisolated static func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else { return nil }
        let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        let assets = json["assets"] as? [[String: Any]] ?? []
        let zip = assets.first { asset in
            let name = asset["name"] as? String ?? ""
            return name.hasPrefix("NotchHub") && name.hasSuffix(".zip")
        }
        let download = (zip?["browser_download_url"] as? String).flatMap(URL.init(string:))
        return Release(version: version, pageURL: page, downloadURL: download)
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
