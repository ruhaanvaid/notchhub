// Renders NotchHub's SwiftUI views to PNGs with sample data, for design review.
// Build: see Tools/snapshots.sh
import AppKit
import SwiftUI

@main
enum Snapshots {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        // Sample shelf files.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("notchhub-snap", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let names = ["Quarterly Report.pdf", "IMG_2041.jpeg", "notes.md", "Design v3.fig", "song.mp3"]
        let files = names.map { name -> URL in
            let u = tmp.appendingPathComponent(name); try? "x".write(to: u, atomically: true, encoding: .utf8); return u
        }

        let nowPlaying = NowPlayingService()
        let art = NSImage(size: NSSize(width: 200, height: 200), flipped: false) { r in
            NSGradient(colors: [NSColor.systemPink, NSColor.systemOrange, NSColor.systemPurple])!.draw(in: r, angle: 45)
            return true
        }
        nowPlaying.setPreview(
            track: NowPlayingTrack(player: .spotify, title: "Blinding Lights", artist: "The Weeknd", album: "After Hours",
                                   isPlaying: true, trackID: "1", artworkURL: nil),
            artwork: art
        )
        let volume = VolumeService(); volume.refresh()
        let outputs = AudioOutputService(); outputs.reload()
        let power = PowerService()
        let focus = FocusService()
        let shelfStore = ShelfStore(storeURL: tmp.appendingPathComponent("shelf.json"))
        let context = PanelContext(nowPlaying: nowPlaying, volume: volume, outputs: outputs, power: power,
                                   focus: focus, shelf: shelfStore, openSettings: {})

        let notch = NotchGeometry(displayID: 1, screenFrame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
                                  notchSize: CGSize(width: 185, height: 32), centerX: 864, hasHardwareNotch: true)
        let pill = NotchGeometry(displayID: 3, screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                 notchSize: NotchGeometry.pillSize, centerX: 960, hasHardwareNotch: false)

        func render(_ name: String, geometry: NotchGeometry, configure: (NotchState) -> Void) {
            let state = NotchState()
            state.geometry = geometry
            configure(state)
            let size = NotchLayout.windowSize(for: geometry)
            let view = ZStack(alignment: .top) {
                // Fake desktop + menu bar so black-on-dark contrast is judged honestly.
                LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.32), Color(red: 0.32, green: 0.22, blue: 0.36)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(Color.black.opacity(0.25)).frame(height: geometry.notchSize.height)
                if geometry.hasHardwareNotch {
                    // The hardware notch itself: pixels there are never visible.
                    UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                        .fill(Color.black)
                        .frame(width: geometry.notchSize.width, height: geometry.notchSize.height)
                }
                NotchRootView(state: state, context: context)
            }
            .frame(width: size.width, height: size.height)
            .transaction { $0.disablesAnimations = true }
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                print("failed:", name); return
            }
            try? png.write(to: out.appendingPathComponent("\(name).png"))
            print("wrote", name)
        }

        render("1-idle-notch", geometry: notch) { _ in }
        render("2-idle-notch-awake", geometry: notch) { $0.indicatorVisible = true }
        render("3-hud-volume-notch", geometry: notch) { $0.showHUD(.volume, level: 0.62) }
        render("4-hud-brightness-pill", geometry: pill) { $0.showHUD(.brightness, level: 0.35) }
        render("4b-hud-volume-notch-100", geometry: notch) { $0.showHUD(.volume, level: 1.0) }
        render("4e-hud-volume-notch-fine", geometry: notch) { $0.showHUD(.volume, level: 10.25 / 16) }
        render("4f-hud-volume-pill-11", geometry: pill) { $0.showHUD(.volume, level: 11.0 / 16) }
        render("4g-hud-volume-notch-muted", geometry: notch) { $0.showHUD(.volume, level: 0) }
        render("4c-hud-brightness-notch", geometry: notch) { $0.showHUD(.brightness, level: 0.06) }
        render("4d-hud-volume-pill-100", geometry: pill) { $0.showHUD(.volume, level: 1.0) }
        render("5-expanded", geometry: notch) { $0.expand() }
        shelfStore.add(files)
        render("6-expanded-shelf", geometry: notch) { $0.shelfHasItems = true; $0.expand() }
        render("7-expanded-pill-drop", geometry: pill) { $0.isDropTargeted = true; $0.expand() }
        render("8-idle-pill", geometry: pill) { _ in }

        func renderPart<V: View>(_ name: String, _ v: V) {
            let view = v.frame(width: 384).padding(16).background(Color.black).environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: out.appendingPathComponent("part-\(name).png")); print("wrote part", name)
            }
        }
        renderPart("header", HeaderBar(context: context, notchWidth: 185, height: 32))
        renderPart("nowplaying", NowPlayingView(service: nowPlaying))
        let youtube = NowPlayingService()
        youtube.setPreview(
            track: NowPlayingTrack(player: .chrome, title: "Me at the zoo", artist: "", album: "", isPlaying: false,
                                   trackID: "jNQXAC9IVRw", artworkURL: nil, canControl: false),
            artwork: art
        )
        renderPart("nowplaying-youtube-no-js", NowPlayingView(service: youtube))
        let netflix = NowPlayingService()
        netflix.setPreview(
            track: NowPlayingTrack(player: .chrome, title: "Netflix", artist: "", album: "Netflix", isPlaying: true,
                                   trackID: "netflix", artworkURL: nil, canControl: false),
            artwork: nil
        )
        renderPart("nowplaying-netflix-no-js", NowPlayingView(service: netflix))
        let twitch = NowPlayingService()
        twitch.setPreview(
            track: NowPlayingTrack(player: .safari, title: "Some streamer", artist: "", album: "Twitch", isPlaying: true,
                                   trackID: "twitch", artworkURL: nil, canControl: false),
            artwork: nil
        )
        renderPart("nowplaying-twitch-no-js", NowPlayingView(service: twitch))
        renderPart("volume", VolumeRow(volume: volume))
        renderPart("shelf", ShelfRowView(shelf: shelfStore, isTargeted: false).frame(height: 56))

        do {
            // Form is AppKit-backed, so ImageRenderer can't draw it; render it in an
            // off-screen window and capture the view hierarchy instead.
            let hosting = NSHostingView(rootView: SettingsView(focus: focus, permissions: PermissionsManager(), updates: UpdateService()))
            hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 640)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = hosting
            for _ in 0..<20 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)); hosting.layoutSubtreeIfNeeded() }
            if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
                hosting.cacheDisplay(in: hosting.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: out.appendingPathComponent("10-settings.png")); print("wrote 10-settings")
                }
            }
        }

        // The expanded panel without NotchRootView's insertion transition, which
        // ImageRenderer captures part-way through (it dims everything).
        do {
            let state = NotchState()
            state.geometry = notch
            state.shelfHasItems = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] == "shelf" : true
            state.expand()
            let m = state.metrics!
            let view = ZStack(alignment: .top) {
                NotchShape(topRadius: m.topRadius, bottomRadius: m.bottomRadius).fill(Color.black)
                ExpandedPanelView(state: state, context: context, geometry: notch)
                    .padding(.horizontal, m.topRadius + 18)
                    .padding(.bottom, 16)
            }
            .frame(width: m.shapeSize.width, height: m.shapeSize.height)
            .environment(\.colorScheme, .dark)
            .padding(24)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.32), Color(red: 0.32, green: 0.22, blue: 0.36)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: out.appendingPathComponent("9-expanded-direct.png"))
                print("wrote 9-expanded-direct")
            }
        }
    }
}
