import Foundation

/// A tab in a specific browser window (window id + 1-based tab index), for sending controls back.
struct BrowserTab: Equatable, Sendable {
    var windowID: Int
    var tabIndex: Int
}

/// A streaming site NotchHub recognises in browser tabs.
struct MediaSite: Sendable {
    let name: String
    /// Substrings of the tab URL that mean "this tab is playing (or can play) media".
    let urlPatterns: [String]

    static let all: [MediaSite] = [
        MediaSite(name: "YouTube Music", urlPatterns: ["music.youtube.com"]),
        MediaSite(name: "YouTube", urlPatterns: ["youtube.com/watch", "youtube.com/shorts/", "youtube.com/live/"]),
        MediaSite(name: "Netflix", urlPatterns: ["netflix.com/watch"]),
        MediaSite(name: "Prime Video", urlPatterns: ["primevideo.com", "amazon.com/gp/video"]),
        MediaSite(name: "Disney+", urlPatterns: ["disneyplus.com"]),
        MediaSite(name: "Hulu", urlPatterns: ["hulu.com/watch"]),
        MediaSite(name: "Max", urlPatterns: ["max.com/video", "play.max.com"]),
        MediaSite(name: "Apple TV+", urlPatterns: ["tv.apple.com"]),
        MediaSite(name: "Twitch", urlPatterns: ["twitch.tv/"]),
        MediaSite(name: "Vimeo", urlPatterns: ["vimeo.com/"]),
        MediaSite(name: "Crunchyroll", urlPatterns: ["crunchyroll.com/watch"]),
        MediaSite(name: "Spotify", urlPatterns: ["open.spotify.com"]),
        MediaSite(name: "SoundCloud", urlPatterns: ["soundcloud.com/"]),
    ]

    static func matching(_ url: String) -> MediaSite? {
        all.first { site in site.urlPatterns.contains { url.contains($0) } }
    }
}

/// Media in Safari and Chromium browser tabs (YouTube, Netflix, and the other `MediaSite`s),
/// over AppleScript.
///
/// Two tiers:
/// - Always: tab URLs and titles (Automation permission only), giving a title and, for
///   YouTube, a thumbnail. Whether the browser is playing comes from `AudioActivity`.
/// - When the browser's "Allow JavaScript from Apple Events" option is on: a small page script
///   reads `navigator.mediaSession` and the page's `<video>`/`<audio>` element for the exact
///   title and play state, and controls playback by pressing the site's own buttons.
enum BrowserMedia {
    enum Command { case playPause, next, previous }

    // MARK: - Page scripts (single quotes only; they're embedded in AppleScript strings)

    static let queryJS = """
        (function(){var els=[].slice.call(document.querySelectorAll('video,audio'));\
        var v=els.filter(function(e){return !e.paused&&!e.ended;})[0]||els[0];\
        var m=navigator.mediaSession?navigator.mediaSession.metadata:null;\
        var art='';if(m&&m.artwork&&m.artwork.length){art=m.artwork[m.artwork.length-1].src;}\
        var t=(m&&m.title)?m.title:'';var a=(m&&m.artist)?m.artist:'';\
        if(!t){var h=document.querySelector('[data-uia=video-title], .atvwebplayersdk-title-text, [data-testid=stream-info-card-component__title]');if(h){t=h.textContent.trim();}}\
        if(!a){var c=document.querySelector('ytd-watch-metadata ytd-channel-name a');if(c){a=c.textContent.trim();}}\
        return JSON.stringify({v:!!v,p:!!(v&&!v.paused&&!v.ended),t:t,a:a,art:art});})()
        """

    static func controlJS(_ command: Command) -> String {
        switch command {
        case .playPause:
            return "(function(){var els=[].slice.call(document.querySelectorAll('video,audio'));var v=els.filter(function(e){return !e.paused&&!e.ended;})[0]||els[0];if(!v){return 'no';}if(v.paused){v.play();}else{v.pause();}return 'ok';})()"
        case .next:
            return "(function(){var b=document.querySelector('ytmusic-player-bar .next-button, .ytp-next-button, [data-uia=control-next], [data-testid=control-button-skip-forward], .skipControl__next');if(b){b.click();return 'ok';}return 'no';})()"
        case .previous:
            return "(function(){var b=document.querySelector('ytmusic-player-bar .previous-button, [data-testid=control-button-skip-back], .skipControl__previous');if(b){b.click();return 'ok';}if(location.host.indexOf('youtube.com')>=0){var v=document.querySelector('video');if(v){v.currentTime=0;}}return 'ok';})()"
        }
    }

    // MARK: - AppleScript

    static func queryScript(for browser: MediaPlayer) -> String {
        let isSafari = browser == .safari
        let titleProperty = isSafari ? "name" : "title"
        let runJS = isSafari
            ? "do JavaScript \(literal(queryJS)) in theTab"
            : "execute theTab javascript \(literal(queryJS))"
        let activeIndex = isSafari ? "index of current tab of theWindow" : "active tab index of theWindow"
        let patterns = MediaSite.all.flatMap(\.urlPatterns)
        let urlCondition = patterns.map { "tabURL contains \(literal($0))" }.joined(separator: " or ")
        // Long variable names: short ones collide with AppleScript keywords.
        return """
            tell application id "\(browser.bundleIdentifier)"
                set sepChar to character id 30
                set recChar to character id 31
                set collected to ""
                set windowOrder to 0
                repeat with theWindow in windows
                    try
                        set windowOrder to windowOrder + 1
                        set windowIdent to id of theWindow
                        set activeNumber to 0
                        try
                            set activeNumber to \(activeIndex)
                        end try
                        set tabNumber to 0
                        repeat with theTab in tabs of theWindow
                            set tabNumber to tabNumber + 1
                            set tabURL to URL of theTab
                            if tabURL is not missing value and (\(urlCondition)) then
                                set pageInfo to ""
                                try
                                    set pageInfo to \(runJS)
                                on error
                                    set pageInfo to "ERR"
                                end try
                                if pageInfo is missing value then set pageInfo to ""
                                set tabTitle to \(titleProperty) of theTab
                                if tabTitle is missing value then set tabTitle to ""
                                set isActive to "0"
                                if tabNumber = activeNumber then set isActive to "1"
                                set collected to collected & (windowIdent as string) & sepChar & (tabNumber as string) & sepChar & tabURL & sepChar & tabTitle & sepChar & pageInfo & sepChar & isActive & sepChar & (windowOrder as string) & recChar
                            end if
                        end repeat
                    end try
                end repeat
                return collected
            end tell
            """
    }

    static func controlScript(_ command: Command, browser: MediaPlayer, tab: BrowserTab) -> String {
        let js = literal(controlJS(command))
        let target = "tab \(tab.tabIndex) of window id \(tab.windowID)"
        if browser == .safari {
            return "tell application id \"\(browser.bundleIdentifier)\" to do JavaScript \(js) in \(target)"
        }
        return "tell application id \"\(browser.bundleIdentifier)\" to execute \(target) javascript \(js)"
    }

    /// An AppleScript string literal.
    private static func literal(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    // MARK: - Parsing

    /// Parses the query output. `browserIsPlaying` (from `AudioActivity`) stands in for the
    /// play state of tabs whose page script couldn't run; it's credited to one tab only:
    /// the active tab of the frontmost window, else any active tab, else the first.
    static func parse(_ output: String?, browser: MediaPlayer, browserIsPlaying: Bool = false) -> [NowPlayingTrack] {
        guard let output, !output.isEmpty else { return [] }
        struct Row { var track: NowPlayingTrack; var isActive: Bool; var windowOrder: Int }

        var rows: [Row] = output.split(separator: Character(UnicodeScalar(31))).compactMap { record in
            let fields = record.split(separator: Character(UnicodeScalar(30)), omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count >= 5,
                  let windowID = Int(fields[0]), let tabIndex = Int(fields[1]),
                  let track = track(
                      browser: browser,
                      tab: BrowserTab(windowID: windowID, tabIndex: tabIndex),
                      pageURL: fields[2], tabTitle: fields[3], pageInfo: fields[4]
                  )
            else { return nil }
            let isActive = fields.count > 5 && fields[5] == "1"
            let order = fields.count > 6 ? Int(fields[6]) ?? Int.max : Int.max
            return Row(track: track, isActive: isActive, windowOrder: order)
        }

        // Without a page script, use the browser's audio as the play state of its likeliest tab.
        if browserIsPlaying, !rows.contains(where: { $0.track.canControl && $0.track.isPlaying }) {
            let candidates = rows.indices.filter { !rows[$0].track.canControl }
            let best = candidates.min { a, b in
                (rows[a].isActive ? 0 : 1, rows[a].windowOrder) < (rows[b].isActive ? 0 : 1, rows[b].windowOrder)
            }
            if let best { rows[best].track.isPlaying = true }
        }
        return rows.map(\.track)
    }

    private static func track(
        browser: MediaPlayer, tab: BrowserTab, pageURL: String, tabTitle: String, pageInfo: String
    ) -> NowPlayingTrack? {
        guard let site = MediaSite.matching(pageURL) else { return nil }
        let fallbackTitle = cleanTitle(tabTitle, site: site)

        if let data = pageInfo.data(using: .utf8),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Page script ran: exact information. Pages without a media element are skipped.
            guard info["v"] as? Bool == true else { return nil }
            let scripted = (info["t"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let title = scripted ?? fallbackTitle
            guard !title.isEmpty else { return nil }
            let art = (info["art"] as? String).flatMap { URL(string: $0) } ?? thumbnailURL(for: pageURL)
            return NowPlayingTrack(
                player: browser, title: title, artist: info["a"] as? String ?? "", album: site.name,
                isPlaying: info["p"] as? Bool ?? false, trackID: videoID(in: pageURL) ?? pageURL,
                artworkURL: art, tab: tab, canControl: true
            )
        }

        // JavaScript from Apple Events is off: title (and YouTube thumbnail) only.
        guard !fallbackTitle.isEmpty else { return nil }
        // Site home pages (e.g. YouTube Music with nothing queued) aren't media.
        if fallbackTitle == site.name, site.name == "YouTube Music" { return nil }
        return NowPlayingTrack(
            player: browser, title: fallbackTitle, artist: "", album: site.name,
            isPlaying: false, trackID: videoID(in: pageURL) ?? pageURL,
            artworkURL: thumbnailURL(for: pageURL), tab: tab, canControl: false
        )
    }

    /// Strips notification counts and the site's name from a tab title:
    /// "(3) Song - YouTube" → "Song", "Prime Video: Movie" → "Movie", "Netflix" → "Netflix".
    static func cleanTitle(_ title: String, site: MediaSite? = nil) -> String {
        var result = title.trimmingCharacters(in: .whitespaces)
        if let range = result.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        let names = (site.map { [$0.name] } ?? []) + ["YouTube Music", "YouTube"]
        for name in names {
            for separator in [" - ", " | ", " – ", " — ", " • ", " on "] where result.hasSuffix(separator + name) {
                result.removeLast((separator + name).count)
            }
            if result.hasPrefix(name + ": ") { result.removeFirst(name.count + 2) }
            if result.hasPrefix("Watch "), result.hasSuffix(" | " + name) { result.removeFirst(6) }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func videoID(in pageURL: String) -> String? {
        guard pageURL.contains("youtube.com"), let components = URLComponents(string: pageURL) else { return nil }
        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
            return id
        }
        let parts = components.path.split(separator: "/")
        if parts.count >= 2, parts[0] == "shorts" || parts[0] == "live" { return String(parts[1]) }
        return nil
    }

    /// 16:9 YouTube thumbnail without letterbox bars.
    static func thumbnailURL(for pageURL: String) -> URL? {
        videoID(in: pageURL).flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/mqdefault.jpg") }
    }
}
