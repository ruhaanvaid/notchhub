import SwiftUI

/// One row: artwork with a soft glow in its own colour, title and artist, transport controls.
struct NowPlayingView: View {
    let service: NowPlayingService
    /// Opens Settings, which has the full explanation of browser playback controls.
    var openSettings: () -> Void = {}

    /// Showing the short "how to get playback controls" note in place of the row.
    @State private var showingControlsHelp = false

    var body: some View {
        Group {
            if showingControlsHelp, let track = service.track, !track.canControl {
                controlsHelp(for: track)
                    .transition(.opacity)
            } else {
                row.transition(.opacity)
            }
        }
        .frame(height: 56)
        .animation(.easeOut(duration: 0.2), value: showingControlsHelp)
        .onChange(of: service.track?.canControl) { _, canControl in
            if canControl != false { showingControlsHelp = false }
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NotchStyle.titleFont)
                    .foregroundStyle(service.track == nil ? NotchStyle.secondary : NotchStyle.primary)
                    .lineLimit(1)
                subtitle
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let track = service.track, !track.canControl {
                // Browser media without "Allow JavaScript from Apple Events": no buttons yet.
                Button { showingControlsHelp = true } label: {
                    Text("Playback controls")
                        .font(NotchStyle.captionFont)
                        .foregroundStyle(NotchStyle.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(NotchStyle.fillStrong, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("How to get play, pause and skip buttons for \(track.player.displayName)")
            } else if let track = service.track {
                HStack(spacing: 6) {
                    if let favorite = track.isFavorite {
                        // Music's heart (Spotify's scripting can't like songs).
                        Button(action: service.toggleFavorite) {
                            Image(systemName: favorite ? "heart.fill" : "heart")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(favorite ? Color.pink : NotchStyle.secondary)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 26, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(favorite ? "Remove from Favorites" : "Add to Favorites")
                    }
                    TransportButton(symbol: "backward.fill", size: 13, action: service.previousTrack)
                    TransportButton(
                        symbol: track.isPlaying ? "pause.fill" : "play.fill",
                        size: 20,
                        action: service.playPause
                    )
                    TransportButton(symbol: "forward.fill", size: 13, action: service.nextTrack)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: service.track)
    }

    /// Why there are no buttons, and the one browser setting that adds them.
    private func controlsHelp(for track: NowPlayingTrack) -> some View {
        let browser = track.player.displayName
        let path = track.player == .safari
            ? "Safari › Develop › Allow JavaScript from Apple Events"
            : "\(browser) › View › Developer › Allow JavaScript from Apple Events"
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "playpause.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 56, height: 56)
                .background(NotchStyle.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Play/pause and skip need one \(browser) setting:")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(path)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                Button("Details") { openSettings() }
                    .buttonStyle(.plain)
                    .font(NotchStyle.captionFont)
                    .foregroundStyle(NotchStyle.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(NotchStyle.fillStrong, in: Capsule())
                    .help("Opens Settings, which explains what this browser setting allows")
                Button("Done") { showingControlsHelp = false }
                    .buttonStyle(.plain)
                    .font(NotchStyle.captionFont)
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
    }

    private var title: String {
        if let track = service.track { return track.title }
        if let denied = service.permissionDenied { return "Allow access to \(denied.displayName)" }
        return "Not Playing"
    }

    @ViewBuilder
    private var subtitle: some View {
        if let track = service.track {
            Text(track.subtitle)
                .font(NotchStyle.bodyFont)
                .foregroundStyle(NotchStyle.secondary)
                .lineLimit(1)
        } else if service.permissionDenied != nil {
            Button(action: service.openAutomationSettings) {
                Text("Open Privacy Settings")
                    .font(NotchStyle.captionFont)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(NotchStyle.fillStrong, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Text("Play something in Music or Spotify")
                .font(NotchStyle.bodyFont)
                .foregroundStyle(NotchStyle.tertiary)
                .lineLimit(1)
        }
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let site = service.track?.site
        let siteColor = site.map { Color(rgb: $0.color) }
        let tint = service.artworkTint.map(Color.init(nsColor:)) ?? (service.artwork == nil ? siteColor : nil)
        return ZStack {
            shape.fill(NotchStyle.fill)
            if let image = service.artwork, service.track != nil, service.artworkIsLogo {
                // The site's official icon, shown whole inside the tile.
                // Small icons are drawn smaller rather than stretched blurry.
                let side = min(38, max(20, CGFloat(SiteIcons.pixelWidth(of: image)) / 2 * 1.25))
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
            } else if let image = service.artwork, service.track != nil {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let site, let siteColor {
                // A simple coloured tile with the site's initial (not its logo).
                shape.fill(siteColor.gradient)
                Text(site.mark)
                    .font(.system(size: site.mark.count > 1 ? 18 : 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(NotchStyle.tertiary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(shape)
        .background {
            if let tint, service.track != nil {
                shape.fill(tint)
                    .blur(radius: 16)
                    .opacity(0.55)
                    .scaleEffect(1.15)
            }
        }
        .scaleEffect(service.track?.isPlaying == false ? 0.92 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: service.track?.isPlaying)
    }
}

private struct TransportButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                // Explicit: plain buttons are dimmed in windows that aren't key, and the
                // notch panel never is.
                .foregroundStyle(NotchStyle.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    /// From a 0xRRGGBB value.
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

/// Elapsed time, a draggable progress bar, and remaining time. Hidden (but keeping its height)
/// when the source doesn't report a position or length, e.g. live streams.
struct TrackProgressView: View {
    let service: NowPlayingService

    /// While dragging, the position under the pointer (seconds).
    @State private var scrubbing: Double?

    var body: some View {
        Group {
            if let track = service.track, let duration = track.duration, duration > 0, track.position != nil {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = scrubbing ?? track.currentPosition(at: context.date) ?? 0
                    HStack(spacing: 8) {
                        Text(Self.format(position))
                            .frame(width: 38, alignment: .trailing)
                        GeometryReader { proxy in
                            LevelBar(level: position / duration)
                                .frame(height: 4)
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            guard track.canControl else { return }
                                            let fraction = min(max(gesture.location.x / max(proxy.size.width, 1), 0), 1)
                                            scrubbing = fraction * duration
                                        }
                                        .onEnded { _ in
                                            if let target = scrubbing { service.seek(to: target) }
                                            scrubbing = nil
                                        }
                                )
                        }
                        Text("-" + Self.format(max(0, duration - position)))
                            .frame(width: 42, alignment: .leading)
                    }
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(NotchStyle.secondary)
                }
            } else {
                Color.clear
            }
        }
        .frame(height: NotchLayout.progressRowHeight)
    }

    /// "1:05", "1:02:05".
    static func format(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}
