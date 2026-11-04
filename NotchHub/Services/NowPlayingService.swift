import AppKit
import Observation

enum MediaPlayer: String, CaseIterable, Sendable {
    case music
    case spotify

    var bundleIdentifier: String {
        switch self {
        case .music: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }

    var displayName: String {
        switch self {
        case .music: return "Music"
        case .spotify: return "Spotify"
        }
    }

    /// Distributed notification each app posts when playback changes. No permission needed.
    var playbackNotification: Notification.Name {
        switch self {
        case .music: return Notification.Name("com.apple.Music.playerInfo")
        case .spotify: return Notification.Name("com.spotify.client.PlaybackStateChanged")
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
    /// Music persistent ID or Spotify track ID; used to know when to refetch artwork.
    var trackID: String
    var artworkURL: URL?
}

/// What's playing in Music or Spotify, via AppleScript. Avoids the MediaRemote private
/// framework, which recent macOS versions block for third-party apps.
///
/// Updates come from the players' distributed notifications. As a fallback it also polls,
/// but only while the panel is open or something is playing.
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
            observers.append(distributed.addObserver(
                forName: player.playbackNotification, object: nil, queue: .main
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

    func playPause() { send("playpause") }
    func nextTrack() { send("next track") }
    func previousTrack() { send("previous track") }

    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    private func send(_ command: String) {
        guard let player = track?.player, player.isRunning else { return }
        let source = "tell application id \"\(player.bundleIdentifier)\" to \(command)"
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
        for player in MediaPlayer.allCases where player.isRunning {
            switch await runner.run(Self.stateScript(for: player)) {
            case let .success(string, _):
                if let track = Self.parseState(string, player: player) {
                    candidates.append(track)
                }
            case let .failure(code, _):
                if code == AppleScriptRunner.notPermittedError { denied = player }
            }
        }

        permissionDenied = denied
        let chosen = choose(from: candidates)
        if chosen != track {
            track = chosen
        }
        if let chosen { lastActivePlayer = chosen.isPlaying ? chosen.player : lastActivePlayer }
        await updateArtwork(for: chosen)
        updatePolling()
    }

    /// Prefers a playing track; if both are playing, the player that changed last.
    private func choose(from candidates: [NowPlayingTrack]) -> NowPlayingTrack? {
        let playing = candidates.filter(\.isPlaying)
        if playing.count > 1, let last = lastActivePlayer, let match = playing.first(where: { $0.player == last }) {
            return match
        }
        if let first = playing.first { return first }
        if let current = track?.player, let match = candidates.first(where: { $0.player == current }) {
            return match
        }
        return candidates.first
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
        case .spotify:
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
