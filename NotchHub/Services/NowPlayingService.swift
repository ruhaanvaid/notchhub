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
    /// The browser tab's address, for browser media (used to fetch the site's icon).
    var pageURL: String? = nil
    /// Playback position and length in seconds, when the source reports them.
    var position: Double? = nil
    var duration: Double? = nil
    /// When `position` was read, to advance it smoothly between polls.
    var positionDate: Date = Date()
    /// Music's favourite (heart); nil where the source has no such thing.
    var isFavorite: Bool? = nil

    /// The position now, advanced since it was read if playing.
    func currentPosition(at date: Date = Date()) -> Double? {
        guard let position else { return nil }
        let advanced = isPlaying ? position + date.timeIntervalSince(positionDate) : position
        return duration.map { min(advanced, $0) } ?? advanced
    }

    /// Same item in the same state (ignores the moving position), for logging and artwork.
    func isSameItem(as other: NowPlayingTrack?) -> Bool {
        guard let other else { return false }
        return player == other.player && trackID == other.trackID && title == other.title
            && isPlaying == other.isPlaying && canControl == other.canControl
    }

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
    /// The artwork is the streaming site's icon rather than album or video art, so it's shown
    /// smaller, inside a tile.
    private(set) var artworkIsLogo = false
    /// Set when the user has denied NotchHub control of this player.
    private(set) var permissionDenied: MediaPlayer?

    @ObservationIgnored private let runner = AppleScriptRunner()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var browserWatchTimer: Timer?
    @ObservationIgnored private var isPanelOpen = false
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var needsAnotherRefresh = false
    @ObservationIgnored private var artworkKey: String?
    /// The source that was playing most recently; preferred when several are playing or
    /// nothing is.
    @ObservationIgnored private var lastActivePlayer: MediaPlayer? = UserDefaults.standard
        .string(forKey: NowPlayingService.lastPlayedKey).flatMap(MediaPlayer.init(rawValue:)) {
        didSet {
            // Remembered across restarts and updates, so the panel keeps showing what you
            // last played instead of an old paused track.
            if lastActivePlayer != oldValue {
                UserDefaults.standard.set(lastActivePlayer?.rawValue, forKey: Self.lastPlayedKey)
            }
        }
    }
    private static let lastPlayedKey = "lastPlayedSource"

    private let pollInterval: TimeInterval = 2

    func start() {
        let distributed = DistributedNotificationCenter.default()
        for player in MediaPlayer.allCases {
            guard let name = player.playbackNotification else { continue }
            observers.append(distributed.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] note in
                // These fire on pause, track changes and launch too; only real playback
                // makes this the most recently played source.
                let isPlaying = (note.userInfo?["Player State"] as? String) == "Playing"
                MainActor.assumeIsolated {
                    if isPlaying { self?.lastActivePlayer = player }
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
    func seek(to seconds: Double) {
        if var current = track {
            // Move the bar immediately; the next poll confirms.
            current.position = seconds
            current.positionDate = Date()
            track = current
        }
        send(.seek(seconds))
    }

    /// Music's heart. (Spotify's scripting has no way to like or save a song.)
    func toggleFavorite() {
        guard let current = track, current.player == .music, let favorite = current.isFavorite else { return }
        var updated = current
        updated.isFavorite = !favorite
        track = updated
        let source = "tell application id \"com.apple.Music\" to set favorited of current track to \(!favorite)"
        Task {
            _ = await runner.run(source)
            refresh()
        }
    }

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
            case let .seek(seconds): verb = "set player position to \(String(format: "%.2f", seconds))"
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
        if !(chosen?.isSameItem(as: track) ?? (track == nil)) {
            let summary = candidates.map {
                "\($0.player.displayName)/\($0.album.isEmpty ? "-" : $0.album) playing=\($0.isPlaying) controls=\($0.canControl)"
            }.joined(separator: "; ")
            log.info("showing \(chosen.map { "\($0.player.displayName) \($0.album)" } ?? "nothing", privacy: .public) from [\(summary, privacy: .public)]")
        }
        if chosen != track { track = chosen }
        if let chosen { lastActivePlayer = chosen.isPlaying ? chosen.player : lastActivePlayer }
        await updateArtwork(for: chosen)
        updatePolling()
    }

    /// Picks what to show. In order of preference: something playing, the player that was
    /// playing most recently, what's already shown, sources with a known play state, then
    /// Music/Spotify over a browser tab.
    private func choose(from candidates: [NowPlayingTrack]) -> NowPlayingTrack? {
        let current = track
        func score(_ t: NowPlayingTrack) -> (Int, Int, Int, Int, Int) {
            (
                t.isPlaying ? 1 : 0,
                // The last player that was playing wins ties, so pausing Netflix keeps
                // Netflix on screen instead of switching to a paused Music track.
                t.player == lastActivePlayer ? 1 : 0,
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

        // While not polling, watch cheaply for a browser starting to play (its power
        // assertion), so the closed notch's live wings appear without opening the panel.
        // Music and Spotify announce playback themselves.
        let shouldWatch = !shouldPoll && AppSettings.shared.showNowPlaying && AppSettings.shared.includeBrowserMedia
        if shouldWatch, browserWatchTimer == nil {
            browserWatchTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !AudioActivity.playingBrowsers().isEmpty else { return }
                    self.refresh()
                }
            }
        } else if !shouldWatch {
            browserWatchTimer?.invalidate()
            browserWatchTimer = nil
        }
    }

    // MARK: - Artwork

    private func updateArtwork(for track: NowPlayingTrack?) async {
        guard let track else {
            artworkKey = nil
            artwork = nil
            artworkIsLogo = false
            return
        }
        let key = "\(track.player.rawValue):\(track.trackID):\(track.artworkURL?.absoluteString ?? "")"
        guard key != artworkKey else { return }
        artworkKey = key

        var image: NSImage?
        var isLogo = false
        switch track.player {
        case _ where track.player.isBrowser:
            (image, isLogo) = await browserArtwork(for: track)
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
        artworkIsLogo = isLogo
        artwork = image
    }

    /// Browser media: album art for music (from the page, else looked up by title), the video's
    /// own artwork for video sites, and otherwise the site's official icon.
    private func browserArtwork(for track: NowPlayingTrack) async -> (NSImage?, Bool) {
        func download(_ url: URL?) async -> NSImage? {
            guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return NSImage(data: data)
        }
        let site = track.site
        if site?.isMusic == true {
            // The page's own artwork (needs JavaScript from Apple Events) is the real album art.
            if track.canControl, let image = await download(track.artworkURL) { return (image, false) }
            if track.title != site?.name,
               let image = await download(await AlbumArtLookup.shared.artworkURL(title: track.title, artist: track.artist)) {
                return (image, false)
            }
        }
        if let image = await download(track.artworkURL) { return (image, false) }
        if let page = track.pageURL,
           let data = await SiteIcons.shared.iconData(forPage: page),
           let image = NSImage(data: data) {
            return (image, true)
        }
        return (nil, false)
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
        let favoriteLine = player == .music
            ? "try\n set favText to (favorited of theTrack) as string\n end try"
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
                set posText to ""
                set durText to ""
                set favText to ""
                try
                    set posText to (player position) as string
                end try
                try
                    set durText to (duration of theTrack) as string
                end try
                \(favoriteLine)
                return playerState & sepChar & trackName & sepChar & trackArtist & sepChar & trackAlbum & sepChar & trackIdent & sepChar & artURL & sepChar & posText & sepChar & durText & sepChar & favText
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
        var track = NowPlayingTrack(
            player: player,
            title: title,
            artist: fields[2],
            album: fields[3],
            isPlaying: fields[0] == "playing",
            trackID: fields[4],
            artworkURL: URL(string: fields[5])
        )
        // AppleScript formats reals with the user's decimal separator.
        func number(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
        if fields.count >= 9 {
            track.position = number(fields[6])
            if var length = number(fields[7]), length > 0 {
                // Spotify reports milliseconds despite its dictionary saying seconds.
                if player == .spotify, length > 10_000 { length /= 1000 }
                track.duration = length
            }
            track.isFavorite = player == .music && !fields[8].isEmpty ? fields[8] == "true" : nil
        }
        return track
    }
}
