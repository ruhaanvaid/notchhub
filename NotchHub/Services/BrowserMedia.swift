import Foundation

/// A tab in a specific browser window (window id + 1-based tab index), for sending controls back.
struct BrowserTab: Equatable, Sendable {
    var windowID: Int
    var tabIndex: Int
}

/// YouTube and YouTube Music in Safari and Chromium browsers, over AppleScript.
///
/// Two tiers:
/// - Always: tab URLs and titles (Automation permission only), giving the video title and
///   thumbnail, but not play state or controls.
/// - When the browser's "Allow JavaScript from Apple Events" option is on: a small page script
///   reads `navigator.mediaSession` and the `<video>` element for play state, and controls
///   playback by clicking YouTube's own buttons.
enum BrowserMedia {
    enum Command { case playPause, next, previous }

    /// Matches YouTube watch pages, Shorts, and YouTube Music.
    private static let urlTests = [
        "youtube.com/watch", "youtube.com/shorts/", "music.youtube.com",
    ]

    // MARK: - Page scripts (single quotes only; they're embedded in AppleScript strings)

    static let queryJS = """
        (function(){var v=document.querySelector('video');\
        var m=navigator.mediaSession?navigator.mediaSession.metadata:null;\
        var art='';if(m&&m.artwork&&m.artwork.length){art=m.artwork[m.artwork.length-1].src;}\
        var t=(m&&m.title)?m.title:'';var a=(m&&m.artist)?m.artist:'';\
        if(!a){var c=document.querySelector('ytd-watch-metadata ytd-channel-name a');if(c){a=c.textContent.trim();}}\
        return JSON.stringify({v:!!v,p:!!(v&&!v.paused&&!v.ended),t:t,a:a,art:art});})()
        """

    static func controlJS(_ command: Command) -> String {
        switch command {
        case .playPause:
            return "(function(){var v=document.querySelector('video');if(!v){return 'no';}if(v.paused){v.play();}else{v.pause();}return 'ok';})()"
        case .next:
            return "(function(){var b=document.querySelector('ytmusic-player-bar .next-button, .ytp-next-button');if(b){b.click();return 'ok';}return 'no';})()"
        case .previous:
            return "(function(){var b=document.querySelector('ytmusic-player-bar .previous-button');if(b){b.click();return 'ok';}var v=document.querySelector('video');if(v){v.currentTime=0;}return 'ok';})()"
        }
    }

    // MARK: - AppleScript

    static func queryScript(for browser: MediaPlayer) -> String {
        let isSafari = browser == .safari
        let titleProperty = isSafari ? "name" : "title"
        let runJS = isSafari
            ? "do JavaScript \(literal(queryJS)) in theTab"
            : "execute theTab javascript \(literal(queryJS))"
        let urlCondition = urlTests.map { "tabURL contains \(literal($0))" }.joined(separator: " or ")
        // Long variable names: short ones collide with AppleScript keywords.
        return """
            tell application id "\(browser.bundleIdentifier)"
                set sepChar to character id 30
                set recChar to character id 31
                set collected to ""
                repeat with theWindow in windows
                    try
                        set windowIdent to id of theWindow
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
                                set collected to collected & (windowIdent as string) & sepChar & (tabNumber as string) & sepChar & tabURL & sepChar & tabTitle & sepChar & pageInfo & recChar
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

    static func parse(_ output: String?, browser: MediaPlayer) -> [NowPlayingTrack] {
        guard let output, !output.isEmpty else { return [] }
        return output.split(separator: Character(UnicodeScalar(31))).compactMap { record in
            let fields = record.split(separator: Character(UnicodeScalar(30)), omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count >= 5,
                  let windowID = Int(fields[0]), let tabIndex = Int(fields[1])
            else { return nil }
            return track(
                browser: browser,
                tab: BrowserTab(windowID: windowID, tabIndex: tabIndex),
                pageURL: fields[2],
                tabTitle: fields[3],
                pageInfo: fields[4]
            )
        }
    }

    private static func track(
        browser: MediaPlayer, tab: BrowserTab, pageURL: String, tabTitle: String, pageInfo: String
    ) -> NowPlayingTrack? {
        let fallbackTitle = cleanTitle(tabTitle)
        let isMusic = pageURL.contains("music.youtube.com")

        if let data = pageInfo.data(using: .utf8),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Page script ran: full information.
            guard info["v"] as? Bool == true else { return nil }
            let title = (info["t"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle
            guard !title.isEmpty, title != "YouTube Music" else { return nil }
            let art = (info["art"] as? String).flatMap { URL(string: $0) } ?? thumbnailURL(for: pageURL)
            return NowPlayingTrack(
                player: browser, title: title, artist: info["a"] as? String ?? "", album: "",
                isPlaying: info["p"] as? Bool ?? false, trackID: videoID(in: pageURL) ?? pageURL,
                artworkURL: art, tab: tab, canControl: true
            )
        }

        // JavaScript from Apple Events is off: title and thumbnail only.
        guard !fallbackTitle.isEmpty, !(isMusic && fallbackTitle == "YouTube Music") else { return nil }
        return NowPlayingTrack(
            player: browser, title: fallbackTitle, artist: "", album: "",
            isPlaying: false, trackID: videoID(in: pageURL) ?? pageURL,
            artworkURL: thumbnailURL(for: pageURL), tab: tab, canControl: false
        )
    }

    /// "(3) Song Title - YouTube" → "Song Title"
    static func cleanTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespaces)
        if let range = result.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        for suffix in [" - YouTube Music", " - YouTube"] where result.hasSuffix(suffix) {
            result.removeLast(suffix.count)
            break
        }
        return result
    }

    static func videoID(in pageURL: String) -> String? {
        guard let components = URLComponents(string: pageURL) else { return nil }
        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
            return id
        }
        let parts = components.path.split(separator: "/")
        if parts.count >= 2, parts[0] == "shorts" { return String(parts[1]) }
        return nil
    }

    /// 16:9 thumbnail without letterbox bars.
    static func thumbnailURL(for pageURL: String) -> URL? {
        videoID(in: pageURL).flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/mqdefault.jpg") }
    }
}
