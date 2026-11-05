import SwiftUI

struct SettingsView: View {
    let focus: FocusService
    let permissions: PermissionsManager
    @Bindable private var settings = AppSettings.shared

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.requiresApproval
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in applyLaunchAtLogin(newValue) }
                if needsApproval {
                    note("Approve NotchHub in System Settings › General › Login Items.")
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle(isOn: $settings.showMainScreenPill) {
                    Text("Show a pill on the main display")
                    Text("When the main display isn't the MacBook screen, a small pill at its top center opens the same panel.")
                }
                Toggle(isOn: $settings.hideInFullScreen) {
                    Text("Hide during full-screen apps")
                    Text("The volume and brightness HUD still appears briefly.")
                }
            }

            Section("Volume & Brightness") {
                permissionRow
                Toggle("Replace the volume overlay", isOn: $settings.replaceVolumeHUD)
                Toggle("Replace the brightness overlay", isOn: $settings.replaceBrightnessHUD)
                LabeledContent("Show for") {
                    HStack(spacing: 10) {
                        Slider(value: $settings.hudDuration, in: AppSettings.hudDurationRange, step: 0.5)
                            .frame(width: 160)
                        Text(settings.hudDuration, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            + Text(" s")
                    }
                }
                .disabled(!settings.replaceVolumeHUD && !settings.replaceBrightnessHUD)
            }

            Section("Panel") {
                Toggle(isOn: $settings.showNowPlaying) {
                    Text("Now playing")
                    Text("Music and Spotify. Uses Automation permission for each app.")
                }
                Toggle(isOn: $settings.includeBrowserMedia) {
                    Text("Include YouTube in browsers")
                    Text("Safari, Chrome, Arc, Brave and Edge. Shows the video title; see below for controls.")
                }
                .disabled(!settings.showNowPlaying)
                if settings.showNowPlaying && settings.includeBrowserMedia {
                    YouTubeControlsNote()
                }
                Toggle("Volume slider and output picker", isOn: $settings.showAudioControls)
                Toggle("Keep Awake button", isOn: $settings.showKeepAwake)
                Toggle("Do Not Disturb button", isOn: $settings.showFocus)
                Toggle(isOn: $settings.shelfEnabled) {
                    Text("File shelf")
                    Text("Drag files onto the notch to park them. Files stay where they are.")
                }
            }

            if settings.showFocus {
                FocusSetupSection(focus: focus)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
        .onAppear {
            focus.checkSetup()
            permissions.refresh()
            launchAtLogin = LaunchAtLogin.isEnabled
            needsApproval = LaunchAtLogin.requiresApproval
        }
    }

    @ViewBuilder
    private var permissionRow: some View {
        if permissions.isAccessibilityTrusted {
            Label("Permission granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Permission needed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    note("Switch NotchHub on in Privacy & Security › \(PermissionsManager.accessibilityPaneName). Until then macOS shows its own overlay.")
                }
                Spacer()
                Button("Grant Access…") { permissions.showOnboarding() }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard enabled != LaunchAtLogin.isEnabled else { return }
        do {
            try LaunchAtLogin.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        needsApproval = LaunchAtLogin.requiresApproval
    }
}

/// How to get play state and controls for YouTube, and what it costs.
private struct YouTubeControlsNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To see whether YouTube is playing and control it, turn on **Allow JavaScript from Apple Events** in your browser:")
            Text("• Chrome, Arc, Brave, Edge: **View › Developer › Allow JavaScript from Apple Events**")
            Text("• Safari: **Settings › Advanced › Show features for web developers**, then **Develop › Allow JavaScript from Apple Events**")
            Text("This lets apps you've allowed to control that browser run scripts in its pages, so only turn it on if you're comfortable with that. NotchHub only runs a short script on YouTube tabs, to read the title and play state and press play, pause, or next.")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One-time setup for the Do Not Disturb button.
private struct FocusSetupSection: View {
    let focus: FocusService

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("macOS has no public API for Focus, so NotchHub runs two Shortcuts you create once:")
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    step(1, "Open Shortcuts and create a new shortcut.")
                    step(2, "Add the **Set Focus** action, set it to turn **Do Not Disturb** **On**, “Until Turned Off”.")
                    step(3, "Name it exactly **\(FocusService.onShortcutName)**.")
                    step(4, "Create a second shortcut that turns Do Not Disturb **Off**, named **\(FocusService.offShortcutName)**.")
                }
                .font(.callout)

                Text("NotchHub can't read the current Focus state, so the button shows what it last set. If you change Focus elsewhere, tap the button twice to resync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    status
                    Spacer()
                    Button("Check Again", action: focus.checkSetup)
                    Button("Open Shortcuts", action: focus.openShortcutsApp)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Do Not Disturb Setup")
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch focus.setupState {
        case .unknown:
            Label("Checking…", systemImage: "ellipsis.circle")
                .foregroundStyle(.secondary)
        case .ready:
            Label("Both shortcuts found", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .missing(names):
            Label("Missing: \(names.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
    }
}
