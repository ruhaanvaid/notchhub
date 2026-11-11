import AppKit

/// Official site icons for browser media (the icon the site itself publishes, as a browser's
/// favicon would be), fetched from the site and cached on disk. Nothing is bundled with
/// NotchHub, and the only request goes to the site the user already has open.
actor SiteIcons {
    static let shared = SiteIcons()

    private var memory: [String: Data] = [:]
    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("com.notchhub.app/SiteIcons", isDirectory: true)
    }()
    private let cacheLifetime: TimeInterval = 30 * 24 * 60 * 60

    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// Image data for the site hosting `pageURL`, or nil if none could be found.
    func iconData(forPage pageURL: String) async -> Data? {
        guard let page = URL(string: pageURL), let host = page.host, let scheme = page.scheme else { return nil }
        if let cached = memory[host] { return cached }

        let file = cacheDirectory.appendingPathComponent(host + ".icon")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < cacheLifetime,
           let data = try? Data(contentsOf: file) {
            memory[host] = data
            return data
        }

        let origin = URL(string: "\(scheme)://\(host)/")!
        var candidates = await declaredIcons(at: origin)
        for fallback in ["apple-touch-icon.png", "favicon.ico"] {
            let url = origin.appendingPathComponent(fallback)
            if !candidates.contains(url) { candidates.append(url) }
        }

        // Keep the sharpest icon; stop early once one is big enough for the tile.
        var best: (data: Data, pixels: Int)?
        for url in candidates.prefix(6) {
            guard let data = await fetch(url, limit: 2_000_000),
                  let image = NSImage(data: data), image.isValid
            else { continue }
            let pixels = Self.pixelWidth(of: image)
            guard pixels >= 16 else { continue }
            if pixels > (best?.pixels ?? 0) { best = (data, pixels) }
            if pixels >= 128 { break }
        }
        guard let best else { return nil }
        memory[host] = best.data
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? best.data.write(to: file, options: .atomic)
        return best.data
    }

    /// Largest pixel width among the image's representations (ICO files hold several sizes).
    nonisolated static func pixelWidth(of image: NSImage) -> Int {
        let widths = image.representations.map(\.pixelsWide).filter { $0 > 0 }
        return widths.max() ?? Int(image.size.width)
    }

    /// Icons declared with `<link rel="…icon…">` on the site's home page, best first:
    /// apple-touch icons, then the largest declared size. Monochrome mask icons are skipped.
    private func declaredIcons(at origin: URL) async -> [URL] {
        // Some home pages are large (YouTube's is ~900 KB); icon links are in the <head>.
        guard let data = await fetch(origin, limit: 4_000_000),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return [] }

        let tagPattern = try! NSRegularExpression(pattern: #"<link\b[^>]*>"#, options: .caseInsensitive)
        let attributePattern = try! NSRegularExpression(
            pattern: #"([a-zA-Z][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')"#
        )
        let range = NSRange(html.startIndex..., in: html)
        var scored: [(score: Int, url: URL)] = []

        for match in tagPattern.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])
            var attributes: [String: String] = [:]
            for attribute in attributePattern.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
                guard let nameRange = Range(attribute.range(at: 1), in: tag) else { continue }
                let valueRange = Range(attribute.range(at: 2), in: tag) ?? Range(attribute.range(at: 3), in: tag)
                attributes[tag[nameRange].lowercased()] = valueRange.map { String(tag[$0]) } ?? ""
            }
            let rel = (attributes["rel"] ?? "").lowercased()
            guard rel.contains("icon"), !rel.contains("mask"),
                  let href = attributes["href"]?.replacingOccurrences(of: "&amp;", with: "&"),
                  let url = URL(string: href, relativeTo: origin)?.absoluteURL
            else { continue }

            let size = (attributes["sizes"] ?? "").split(separator: "x").first.flatMap { Int($0) } ?? 0
            var score = size
            if rel.contains("apple-touch") { score += 1_000 + max(size, 180) }
            if url.pathExtension.lowercased() == "ico" { score -= 100 }
            scored.append((score, url))
        }
        return scored.sorted { $0.score > $1.score }.map(\.url)
    }

    private func fetch(_ url: URL, limit: Int) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              data.count <= limit
        else { return nil }
        return data
    }
}

/// Album art for songs playing in a browser (YouTube Music, Spotify web, SoundCloud), looked up
/// by title and artist with Apple's public iTunes Search API (no account or key).
actor AlbumArtLookup {
    static let shared = AlbumArtLookup()
    private var cache: [String: URL?] = [:]

    func artworkURL(title: String, artist: String) async -> URL? {
        let key = (title + "|" + artist).lowercased()
        if let cached = cache[key] { return cached }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: artist.isEmpty ? title : "\(title) \(artist)"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "8"),
        ]
        var found: URL?
        if let url = components.url,
           let (data, _) = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            found = Self.bestMatch(in: results, title: title, artist: artist)
        }
        cache[key] = found
        return found
    }

    /// Prefers an exact title match (and the artist, if known) over remixes and covers.
    nonisolated static func bestMatch(in results: [[String: Any]], title: String, artist: String) -> URL? {
        func normalized(_ text: String) -> String {
            text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
                .trimmingCharacters(in: .whitespaces)
        }
        let wantTitle = normalized(title), wantArtist = normalized(artist)
        func score(_ result: [String: Any]) -> Int {
            let name = normalized(result["trackName"] as? String ?? "")
            let by = normalized(result["artistName"] as? String ?? "")
            var points = 0
            if name == wantTitle { points += 4 } else if name.hasPrefix(wantTitle) { points += 2 }
            if !wantArtist.isEmpty, by.contains(wantArtist) || wantArtist.contains(by) { points += 3 }
            if name.contains("remix") || name.contains("live") || name.contains("karaoke") { points -= 2 }
            return points
        }
        guard let best = results.max(by: { score($0) < score($1) }),
              let small = best["artworkUrl100"] as? String
        else { return nil }
        return URL(string: small.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
    }
}
