import AppKit
import Observation
import OSLog

private let log = Logger(subsystem: "com.notchhub.app", category: "nowplaying")

enum MediaPlayer: String, CaseIterable, Sendable {
    case music
    case spotify
    // Browsers, for YouTube and YouTube Music (see BrowserMedia).
    case safari
    case chrome
    case arc
    case brave
    case edge

    var bundleIdentifier: String {
        switch self {
        case .music: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .arc: return "company.thebrowser.Browser"
        case .brave: return "com.brave.Browser"
        case .edge: return "com.microsoft.edgemac"
        }
    }

    var displayName: String {
        switch self {
        case .music: return "Music"
        case .spotify: return "Spotify"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .arc: return "Arc"
        case .brave: return "Brave"
        case .edge: return "Microsoft Edge"
        }
    }

    var isBrowser: Bool {
        switch self {
        case .music, .spotify: return false
        default: return true
        }
    }

    /// Distributed notification the app posts when playback changes (no permission needed).
    /// Browsers don't post one, so they're only seen by polling.
    var playbackNotification: Notification.Name? {
        switch self {
        case .music: return Notification.Name("com.apple.Music.playerInfo")
        case .spotify: return Notification.Name("com.spotify.client.PlaybackStateChanged")
        default: return nil
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }
}

struct NowPlayingTrack: Equatable {
    var player: MediaPlayer
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    /// Music persistent ID, Spotify track ID, or YouTube video ID; decides when to refetch artwork.
    var trackID: String
    var artworkURL: URL?
    /// The browser tab playing it, for YouTube.
    var tab: BrowserTab? = nil
    /// False for YouTube when the browser doesn't allow JavaScript from Apple Events: the title
    /// is known, but not the play state, and there are no controls.
    var canControl: Bool = true

    /// Second line: the artist/channel, or where it's playing ("Netflix · Google Chrome").
    /// When the title is just the site's name (Netflix tabs are titled "Netflix"), only the
    /// browser is named, so the site doesn't appear twice.
    var subtitle: String {
        if !artist.isEmpty { return artist }
        guard player.isBrowser, !album.isEmpty, album != title else { return player.displayName }
        return "\(album) · \(player.displayName)"
    }

    /// The streaming site, for browser media.
    var site: MediaSite? { player.isBrowser ? MediaSite.named(album) : nil }
}

/// What's playing in Music, Spotify, or YouTube in a browser, via AppleScript. Avoids the
/// MediaRemote private framework, which recent macOS versions block for third-party apps.
///
/// Music and Spotify updates come from their distributed notifications. Browsers have none,
/// so they (and everything, as a fallback) are polled, but only while the panel is open or
/// something is playing.
@Observable
@MainActor
final class NowPlayingService {
    private(set) var track: NowPlayingTrack?
    private(set) var artwork: NSImage? {
        didSet { artworkTint = artwork?.averageColor }
    }
    /// Average colour of the artwork, for the glow behind it.
    private(set) var artworkTint: NSColor?
    /// Set when the user has denied NotchHub control of this player.
    private(set) var permissionDenied: MediaPlayer?

    @ObservationIgnored private let runner = AppleScriptRunner()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var isPanelOpen = false
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var needsAnotherRefresh = false
    @ObservationIgnored private var artworkKey: String?
    /// The player that most recently reported a change; preferred when both are playing.
    @ObservationIgnored private var lastActivePlayer: MediaPlayer?

    private let pollInterval: TimeInterval = 2

    func start() {
        let distributed = DistributedNotificationCenter.default()
        for player in MediaPlayer.allCases {
            guard let name = player.playbackNotification else { continue }
            observers.append(distributed.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.lastActivePlayer = player
                    self?.refresh()
                }
            })
        }

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let bundleID = app?.bundleIdentifier
                MainActor.assumeIsolated {
                    guard MediaPlayer.allCases.contains(where: { $0.bundleIdentifier == bundleID }) else { return }
                    self?.refresh()
                }
            })
        }

        refresh()
    }

    func stop() {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        workspaceObservers.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    #if DEBUG
    /// Snapshot/preview support: show a fixed track without talking to any player.
    func setPreview(track: NowPlayingTrack?, artwork: NSImage?) {
        self.track = track
        self.artwork = artwork
    }
    #endif

    func setPanelOpen(_ open: Bool) {
        isPanelOpen = open
        if open { refresh() }
        updatePolling()
    }

    // MARK: - Controls

    func playPause() { send(.playPause) }
    func nextTrack() { send(.next) }
    func previousTrack() { send(.previous) }

    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    private func send(_ command: BrowserMedia.Command) {
        guard let track, track.canControl, track.player.isRunning else { return }
        let source: String
        if track.player.isBrowser {
            guard let tab = track.tab else { return }
            source = BrowserMedia.controlScript(command, browser: track.player, tab: tab)
        } else {
            let verb: String
            switch command {
            case .playPause: verb = "playpause"
            case .next: verb = "next track"
            case .previous: verb = "previous track"
            }
            source = "tell application id \"\(track.player.bundleIdentifier)\" to \(verb)"
        }
        Task {
            _ = await runner.run(source)
            try? await Task.sleep(for: .milliseconds(250))
            refresh()
        }
    }

    // MARK: - Refresh

    func refresh() {
        guard AppSettings.shared.showNowPlaying else {
            // Turned off in Settings: forget the track and stop talking to the players.
            if track != nil { track = nil }
            artwork = nil
            updatePolling()
            return
        }
        guard !isRefreshing else {
            needsAnotherRefresh = true
            return
        }
        isRefreshing = true
        Task {
            await performRefresh()
            isRefreshing = false
            if needsAnotherRefresh {
                needsAnotherRefresh = false
                refresh()
            }
        }
    }

    private func performRefresh() async {
        var candidates: [NowPlayingTrack] = []
        var denied: MediaPlayer?

        // Only talk to players that are already running: a `tell` would launch them.
        let includeBrowsers = AppSettings.shared.includeBrowserMedia
        // Which apps are making sound: the play state of browser tabs we can't script.
        let audible = includeBrowsers ? AudioActivity.playingBrowsers() : []
        for player in MediaPlayer.allCases where player.isRunning {
            if player.isBrowser, !includeBrowsers { continue }
            let script = player.isBrowser ? BrowserMedia.queryScript(for: player) : Self.stateScript(for: player)
            switch await runner.run(script) {
            case let .success(string, _):
                if player.isBrowser {
                    candidates += BrowserMedia.parse(
                        string, browser: player,
                        browserIsPlaying: audible.contains(player)
                    )
                } else if let track = Self.parseState(string, player: player) {
                    candidates.append(track)
                }
            case let .failure(code, message):
                if code == AppleScriptRunner.notPermittedError { denied = player }
                log.error("\(player.displayName, privacy: .public) query failed (\(code, privacy: .public)): \(message, privacy: .public)")
            }
        }

        permissionDenied = denied
        let chosen = choose(from: candidates)
        if chosen != track {
            let summary = candidates.map {
                "\($0.player.displayName)/\($0.album.isEmpty ? "-" : $0.album) playing=\($0.isPlaying) controls=\($0.canControl)"
            }.joined(separator: "; ")
            log.info("showing \(chosen.map { "\($0.player.displayName) \($0.album)" } ?? "nothing", privacy: .public) from [\(summary, privacy: .public)]")
            track = chosen
        }
        if let chosen { lastActivePlayer = chosen.isPlaying ? chosen.player : lastActivePlayer }
        await updateArtwork(for: chosen)
        updatePolling()
    }

    /// Picks what to show. In order of preference: something playing (the player that changed
    /// last, if several are), what's already shown, sources with a known play state, then
    /// Music/Spotify over a browser tab.
    private func choose(from candidates: [NowPlayingTrack]) -> NowPlayingTrack? {
        let current = track
        func score(_ t: NowPlayingTrack) -> (Int, Int, Int, Int, Int) {
            (
                t.isPlaying ? 1 : 0,
                t.isPlaying && t.player == lastActivePlayer ? 1 : 0,
                t.player == current?.player && t.trackID == current?.trackID ? 1 : 0,
                t.canControl ? 1 : 0,
                t.player.isBrowser ? 0 : 1
            )
        }
        return candidates.max { score($0) < score($1) }
    }

    private func updatePolling() {
        let shouldPoll = AppSettings.shared.showNowPlaying && (isPanelOpen || (track?.isPlaying ?? false))
        if shouldPoll, pollTimer == nil {
            pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        } else if !shouldPoll {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    // MARK: - Artwork

    private func updateArtwork(for track: NowPlayingTrack?) async {
        guard let track else {
            artworkKey = nil
            artwork = nil
            return
        }
        let key = "\(track.player.rawValue):\(track.trackID):\(track.artworkURL?.absoluteString ?? "")"
        guard key != artworkKey else { return }
        artworkKey = key

        var image: NSImage?
        switch track.player {
        case .music:
            if case let .success(_, data) = await runner.run(Self.musicArtworkScript), let data {
                image = NSImage(data: data)
            }
        default:
            // Spotify and YouTube give an artwork URL.
            if let url = track.artworkURL,
               let (data, _) = try? await URLSession.shared.data(from: url) {
                image = NSImage(data: data)
            }
        }

        // Ignore the result if the track changed while fetching.
        guard key == artworkKey else { return }
        artwork = image
    }

    // MARK: - Scripts

    /// Fields are separated by ASCII record separator (30), which won't appear in titles.
    private static let separator = Character(UnicodeScalar(30))

    private static func stateScript(for player: MediaPlayer) -> String {
        // Variable names are deliberately long: short ones like `st` or `a` collide with
        // AppleScript keywords ("1st", the article "a").
        let idField = player == .music ? "persistent ID" : "id"
        let artworkLine = player == .spotify
            ? "try\n set artURL to artwork url of theTrack\n end try"
            : ""
        return """
            tell application id "\(player.bundleIdentifier)"
                set sepChar to character id 30
                set playerState to player state as string
                if playerState is "stopped" then return "stopped"
                set theTrack to current track
                set trackName to ""
                set trackArtist to ""
                set trackAlbum to ""
                set trackIdent to ""
                set artURL to ""
                try
                    set trackName to name of theTrack
                end try
                try
                    set trackArtist to artist of theTrack
                end try
                try
                    set trackAlbum to album of theTrack
                end try
                try
                    set trackIdent to \(idField) of theTrack
                end try
                \(artworkLine)
                return playerState & sepChar & trackName & sepChar & trackArtist & sepChar & trackAlbum & sepChar & trackIdent & sepChar & artURL
            end tell
            """
    }

    private static let musicArtworkScript = """
        tell application id "com.apple.Music"
            try
                return raw data of artwork 1 of current track
            end try
            try
                return data of artwork 1 of current track
            end try
        end tell
        """

    private static func parseState(_ string: String?, player: MediaPlayer) -> NowPlayingTrack? {
        guard let string, string != "stopped" else { return nil }
        let fields = string.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 6 else { return nil }
        let title = fields[1]
        guard !title.isEmpty else { return nil }
        return NowPlayingTrack(
            player: player,
            title: title,
            artist: fields[2],
            album: fields[3],
            isPlaying: fields[0] == "playing",
            trackID: fields[4],
            artworkURL: URL(string: fields[5])
        )
    }
}
