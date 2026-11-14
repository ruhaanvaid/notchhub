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
                if settings.showTimer {
                    TimerMenu(timer: context.timer, size: circleSize)
                }
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

/// Round timer button: pick 5, 10 or 25 minutes; while running it's filled orange and
/// offers Cancel.
private struct TimerMenu: View {
    let timer: TimerService
    let size: CGFloat

    var body: some View {
        Menu {
            ForEach(TimerService.presets, id: \.self) { minutes in
                Button("\(minutes) minutes") { timer.start(minutes: minutes) }
            }
            if timer.isRunning {
                Divider()
                Button("Cancel Timer", role: .destructive) { timer.cancel() }
            }
        } label: {
            ZStack {
                Circle().fill(timer.isRunning ? Color.orange : NotchStyle.fillStrong)
                Image(systemName: "timer")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(timer.isRunning ? Color.black : NotchStyle.primary)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(timer.isRunning ? "Timer running" : "Start a timer")
    }
}
