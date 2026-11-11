import SwiftUI

/// Header row in the band beside the notch: output picker on the left, Awake and Focus
/// toggles on the right, nothing under the camera housing.
struct HeaderBar: View {
    let context: PanelContext
    /// Width of the camera housing to leave empty (0 on a pill).
    let notchWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if settings.showAudioControls {
                    OutputMenu(outputs: context.outputs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: notchWidth > 0 ? notchWidth + 16 : 12)

            HStack(spacing: 8) {
                if settings.showKeepAwake {
                ToggleCircle(
                    symbol: "cup.and.saucer.fill",
                    help: "Keep Awake",
                    isOn: context.power.isKeepingAwake,
                    isBusy: false,
                    size: circleSize,
                    action: context.power.toggle
                )
                }
                if settings.showFocus {
                ToggleCircle(
                    symbol: "moon.fill",
                    help: context.focus.isReady ? "Do Not Disturb" : "Set up Do Not Disturb…",
                    isOn: context.focus.isOn,
                    isBusy: context.focus.isBusy,
                    size: circleSize,
                    action: {
                        if context.focus.isReady {
                            context.focus.toggle()
                        } else {
                            context.openSettings()
                        }
                    }
                )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: height)
    }

    private var circleSize: CGFloat { min(26, height - 6) }
    private var settings: AppSettings { .shared }
}

/// Full-width volume slider with a mute button.
struct VolumeRow: View {
    let volume: VolumeService

    var body: some View {
        HStack(spacing: 10) {
            Button {
                volume.setMuted(!volume.isMuted)
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchStyle.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!volume.canSetMute)

            // Apple's 16 steps, like the HUD: click or drag across the squares.
            SegmentedSlider(value: volume.displayedLevel) { newValue in
                volume.setVolume(newValue)
            }
            .disabled(!volume.canSetVolume)
            .opacity(volume.canSetVolume ? 1 : 0.4)

            // Apple's 16-step scale, matching the HUD.
            Text(VolumeSteps.format(volume.displayedLevel))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(NotchStyle.secondary)
                .contentTransition(.numericText(value: volume.displayedLevel))
                .frame(width: 28, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private var symbol: String {
        volume.displayedLevel < 0.001 ? "speaker.slash.fill" : "speaker.fill"
    }
}

/// The 16-square volume meter as a control. Clicking a square sets the volume to that
/// step; dragging sweeps across them; the far left edge is zero.
struct SegmentedSlider: View {
    let value: Double
    let onChange: (Double) -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            SegmentedLevel(level: value, minSpacing: 3)
                .frame(height: 15)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isEnabled else { return }
                            let steps = Double(VolumeSteps.count)
                            let x = min(max(gesture.location.x, 0), width)
                            let step = x < 3 ? 0 : min(steps, (x / width * steps).rounded(.down) + 1)
                            onChange(step / steps)
                        }
                )
        }
        .frame(height: 20)
    }
}

/// Capsule slider that tracks the pointer from the first click.
struct LevelSlider: View {
    let value: Double
    let onChange: (Double) -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            LevelBar(level: value)
                .frame(height: 6)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isEnabled else { return }
                            onChange(min(max(gesture.location.x / width, 0), 1))
                        }
                )
        }
        .frame(height: 20)
    }
}

private struct OutputMenu: View {
    let outputs: AudioOutputService

    var body: some View {
        Menu {
            ForEach(outputs.devices) { device in
                Button {
                    outputs.select(device)
                } label: {
                    if device.id == outputs.defaultDeviceID {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: outputs.currentDevice?.symbolName ?? "speaker.wave.2")
                    .font(.system(size: 11, weight: .semibold))
                Text(outputs.currentDevice?.shortName ?? "No Output")
                    .font(NotchStyle.captionFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(NotchStyle.tertiary)
            }
            .foregroundStyle(NotchStyle.secondary)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ToggleCircle: View {
    let symbol: String
    let help: String
    let isOn: Bool
    let isBusy: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(isOn ? NotchStyle.primary : NotchStyle.fillStrong)
                if isBusy {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(isOn ? Color.black : NotchStyle.primary)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .help(help)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}
