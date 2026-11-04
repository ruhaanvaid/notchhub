import SwiftUI

/// Friendly explanation of the Accessibility permission, with live status.
struct PermissionsOnboardingView: View {
    let permissions: PermissionsManager
    let onClose: () -> Void

    private var paneName: String { PermissionsManager.accessibilityPaneName }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "speaker.wave.2.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume & brightness in the notch")
                        .font(.title3.weight(.semibold))
                    Text("NotchHub can replace the system volume and brightness overlay with one that lives in the notch.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("To catch the volume and brightness keys, NotchHub needs permission in System Settings › Privacy & Security › **\(paneName)**. It only looks at those keys; every other key passes straight through.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Everything else works without it, and you can grant it later from the menu-bar icon › Permissions…")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            statusRow

            if !permissions.isAccessibilityTrusted {
                Text("NotchHub already switched on but still waiting? Select it, remove it with –, then click Open Settings again. This happens when the app's signature changed since you granted access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                if permissions.isAccessibilityTrusted {
                    Button("Done", action: onClose)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Not Now", action: onClose)
                    Button("Open Settings") {
                        permissions.requestAccessibility()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if permissions.isAccessibilityTrusted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Access granted. The notch HUD is active.")
            } else {
                ProgressView().controlSize(.small)
                Text("Waiting for you to switch NotchHub on in \(paneName)…")
            }
        }
        .font(.callout.weight(.medium))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
