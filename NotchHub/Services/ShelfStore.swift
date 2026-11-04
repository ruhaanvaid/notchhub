import AppKit
import Observation

struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    var url: URL
    var bookmark: Data

    var name: String { FileManager.default.displayName(atPath: url.path) }
}

/// Files parked on the notch. Items are references (bookmarks), not copies: the files stay
/// where they are, and bookmarks follow them if they're moved or renamed. Entries whose file
/// is gone (deleted, or in the Trash) are dropped. Persisted as JSON in Application Support.
@Observable
@MainActor
final class ShelfStore {
    private(set) var items: [ShelfItem] = [] {
        didSet {
            if items.isEmpty != oldValue.isEmpty { onHasItemsChange?(!items.isEmpty) }
        }
    }

    /// Called when the shelf goes from empty to non-empty or back.
    @ObservationIgnored var onHasItemsChange: ((Bool) -> Void)?
    @ObservationIgnored private var icons: [UUID: NSImage] = [:]
    @ObservationIgnored private let storeURL: URL

    private struct StoredItem: Codable {
        var id: UUID
        var bookmark: Data
    }

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? Self.defaultStoreURL
    }

    private static var defaultStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("NotchHub", isDirectory: true)
            .appendingPathComponent("shelf.json")
    }

    // MARK: - Loading and pruning

    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let stored = try? JSONDecoder().decode([StoredItem].self, from: data)
        else { return }

        items = stored.compactMap { entry in
            guard let (url, bookmark) = Self.resolve(entry.bookmark) else { return nil }
            return ShelfItem(id: entry.id, url: url, bookmark: bookmark)
        }
        if items.count != stored.count || zip(items, stored).contains(where: { $0.bookmark != $1.bookmark }) {
            save()
        }
    }

    /// Re-resolves every bookmark: follows moved/renamed files, drops missing ones.
    func pruneMissing() {
        let refreshed = items.compactMap { item -> ShelfItem? in
            guard let (url, bookmark) = Self.resolve(item.bookmark) else { return nil }
            return ShelfItem(id: item.id, url: url, bookmark: bookmark)
        }
        guard refreshed != items else { return }
        let kept = Set(refreshed.map(\.id))
        icons = icons.filter { kept.contains($0.key) }
        items = refreshed
        save()
    }

    // MARK: - Editing

    /// Adds files, skipping ones already on the shelf. Returns how many were added.
    @discardableResult
    func add(_ urls: [URL]) -> Int {
        var known = Set(items.map { $0.url.standardizedFileURL.path })
        var added = 0
        for url in urls where url.isFileURL {
            let standardized = url.standardizedFileURL
            // `insert` also catches the same file appearing twice in one drop.
            guard Self.isAvailable(standardized),
                  known.insert(standardized.path).inserted,
                  let bookmark = try? standardized.bookmarkData()
            else { continue }
            items.append(ShelfItem(id: UUID(), url: standardized, bookmark: bookmark))
            added += 1
        }
        if added > 0 { save() }
        return added
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        icons[item.id] = nil
        save()
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func icon(for item: ShelfItem) -> NSImage {
        if let cached = icons[item.id] { return cached }
        let image = NSWorkspace.shared.icon(forFile: item.url.path)
        image.size = NSSize(width: 64, height: 64)
        icons[item.id] = image
        return image
    }

    // MARK: - Helpers

    private func save() {
        let stored = items.map { StoredItem(id: $0.id, bookmark: $0.bookmark) }
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(stored).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("NotchHub: couldn't save shelf: \(error.localizedDescription)")
        }
    }

    /// Resolves a bookmark to an existing file, refreshing stale bookmark data.
    private static func resolve(_ bookmark: Data) -> (URL, Data)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), isAvailable(url) else { return nil }

        let fresh = isStale ? ((try? url.bookmarkData()) ?? bookmark) : bookmark
        return (url, fresh)
    }

    /// Exists and isn't sitting in the Trash.
    private static func isAvailable(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) && !url.path.contains("/.Trash/")
    }
}
