import SwiftUI

/// One row: artwork with a soft glow in its own colour, title and artist, transport controls.
struct NowPlayingView: View {
    let service: NowPlayingService
    /// Opens Settings, which explains how to enable YouTube controls.
    var openSettings: () -> Void = {}

    var body: some View {
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
                // YouTube without "Allow JavaScript from Apple Events": title only.
                Button(action: openSettings) {
                    Text("Enable controls")
                        .font(NotchStyle.captionFont)
                        .foregroundStyle(NotchStyle.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(NotchStyle.fillStrong, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Shows how to let NotchHub see play state and control YouTube")
            } else if let track = service.track {
                HStack(spacing: 6) {
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
        .frame(height: 56)
        .animation(.easeOut(duration: 0.2), value: service.track)
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
        let tint = service.artworkTint.map(Color.init(nsColor:))
        return ZStack {
            shape.fill(NotchStyle.fill)
            if let image = service.artwork, service.track != nil {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
