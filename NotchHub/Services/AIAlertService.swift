import AppKit
import Observation
import OSLog

private let log = Logger(subsystem: "com.notchhub.app", category: "ai-alerts")

/// An AI tool asking for attention: it needs input (a permission prompt, a question) or it
/// finished a task.
struct AIAlert: Equatable {
    enum Kind: Equatable {
        case needsInput
        case done
        case error
        case info
    }

    var source: String
    var kind: Kind
    var message: String
    /// The project folder's name, when the tool reports its working directory.
    var project: String?
    /// The app to bring forward when the alert is clicked (e.g. Terminal, Claude).
    var appBundleID: String?

    var title: String { project.map { "\(source) · \($0)" } ?? source }
}

/// Receives `notchhub://alert?…` links from the bundled `notchhub-alert` helper, which AI tools
/// call from their hooks (Claude Code's Notification/Stop hooks, Codex's `notify`), and turns
/// them into pop-ups. Also connects Claude Code by adding those hooks to its settings.
@Observable
@MainActor
final class AIAlertService {
    /// Called for each alert to show.
    @ObservationIgnored var onAlert: ((AIAlert) -> Void)?

    /// The bundled helper, `…/NotchHub.app/Contents/Resources/notchhub-alert`.
    static var helperPath: String {
        Bundle.main.url(forResource: "notchhub-alert", withExtension: nil)?.path
            ?? "/Applications/NotchHub.app/Contents/Resources/notchhub-alert"
    }

    // MARK: - Incoming links

    /// Handles `notchhub://alert?source=…&event=…&app=…&payload=…` (values base64url-encoded
    /// by the helper) or plain `notchhub://alert?source=…&message=…&kind=…`.
    func handle(_ url: URL) {
        guard url.scheme == "notchhub", url.host == "alert", AppSettings.shared.aiAlerts,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return }
        func value(_ name: String) -> String? {
            guard let raw = items.first(where: { $0.name == name })?.value, !raw.isEmpty else { return nil }
            return Self.decodeBase64URL(raw) ?? raw
        }

        let source = Self.clean(value("source") ?? "AI", limit: 40)
        let event = (value("event") ?? value("kind") ?? "done").lowercased()
        let payload = value("payload").flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        var kind = Self.kind(for: event, payload: payload)
        var message = value("message") ?? (payload["message"] as? String)
            ?? (payload["last-assistant-message"] as? String) ?? ""
        if message.isEmpty {
            switch kind {
            case .needsInput: message = "Needs your input"
            case .done: message = "Finished"
            case .error: message = "Something went wrong"
            case .info: message = "Update"
            }
        }
        // Claude Code says "Claude is waiting for your input" when idle; that's still input.
        if message.lowercased().contains("waiting for your input") { kind = .needsInput }
        // "Claude needs your permission…" under a "Claude Code" title: drop the repeated name.
        if let firstWord = source.split(separator: " ").first, message.hasPrefix(firstWord + " ") {
            var rest = message.dropFirst(firstWord.count + 1)
            // "Claude is waiting for your input" → "Waiting for your input"
            if rest.hasPrefix("is ") { rest = rest.dropFirst(3) }
            message = rest.prefix(1).uppercased() + rest.dropFirst()
        }

        let cwd = payload["cwd"] as? String
        let project = cwd.map { URL(fileURLWithPath: $0).lastPathComponent }.flatMap { $0.isEmpty ? nil : $0 }
        let app = value("app").flatMap { $0.contains(".") ? $0 : nil }

        let alert = AIAlert(
            source: source, kind: kind, message: Self.clean(message, limit: 140),
            project: project.map { Self.clean($0, limit: 30) }, appBundleID: app
        )
        log.info("alert from \(alert.source, privacy: .public) (\(String(describing: alert.kind), privacy: .public)): \(alert.message, privacy: .public) project=\(alert.project ?? "-", privacy: .public) app=\(alert.appBundleID ?? "-", privacy: .public)")
        if alert.kind == .needsInput, AppSettings.shared.aiAlertSound {
            NSSound(named: "Tink")?.play()
        }
        onAlert?(alert)
    }

    /// Brings the app that raised the alert to the front.
    func activate(_ alert: AIAlert) {
        let candidates = [alert.appBundleID, Self.appBundleID(forSource: alert.source)].compactMap { $0 }
        for id in candidates {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                app.activate()
                return
            }
        }
    }

    /// Icon for the pop-up: the tool's own app icon when it's installed.
    static func icon(for alert: AIAlert) -> NSImage? {
        let ids = [appBundleID(forSource: alert.source), alert.appBundleID].compactMap { $0 }
        for id in ids {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
    }

    private static func appBundleID(forSource source: String) -> String? {
        let name = source.lowercased()
        if name.contains("claude") { return "com.anthropic.claudefordesktop" }
        if name.contains("codex") { return "com.openai.codex" }
        if name.contains("chatgpt") { return "com.openai.chat" }
        if name.contains("copilot") { return "com.microsoft.copilot-mac" }
        if name.contains("cursor") { return "com.todesktop.230313mzl4w4u92" }
        return nil
    }

    private static func kind(for event: String, payload: [String: Any]) -> AIAlert.Kind {
        switch event {
        case "needs-input", "notification", "permission", "input": return .needsInput
        case "error", "failed", "stopfailure": return .error
        case "info": return .info
        default:
            if (payload["hook_event_name"] as? String) == "Notification" { return .needsInput }
            return .done // "done", "stop", Codex's "agent-turn-complete", …
        }
    }

    private static func decodeBase64URL(_ text: String) -> String? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// One line, no control characters, at most `limit` characters.
    private static func clean(_ text: String, limit: Int) -> String {
        let flat = text.components(separatedBy: .newlines).joined(separator: " ")
            .filter { ($0.asciiValue ?? 32) >= 32 } // drop control characters
            .trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit - 1)) + "…" : flat
    }

    // MARK: - Claude Code connection

    static let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    /// Whether ~/.claude/settings.json already has NotchHub's hooks.
    var isClaudeCodeConnected: Bool {
        guard let data = try? Data(contentsOf: Self.claudeSettingsURL),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains("notchhub-alert")
    }

    /// Adds Notification ("needs input") and Stop ("finished") hooks that call the helper.
    /// Keeps every other setting; saves a backup next to the file first.
    func connectClaudeCode() throws {
        var settings = try Self.readClaudeSettings()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for (event, argument) in [("Notification", "Notification"), ("Stop", "done")] {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups.removeAll { Self.isNotchHubGroup($0) }
            groups.append([
                "hooks": [[
                    "type": "command",
                    "command": "/bin/sh '\(Self.helperPath)' 'Claude Code' \(argument)",
                ]],
            ])
            hooks[event] = groups
        }
        settings["hooks"] = hooks
        try Self.writeClaudeSettings(settings)
    }

    /// Removes only NotchHub's hooks.
    func disconnectClaudeCode() throws {
        var settings = try Self.readClaudeSettings()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }
        for event in ["Notification", "Stop"] {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups.removeAll { Self.isNotchHubGroup($0) }
            hooks[event] = groups.isEmpty ? nil : groups
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        try Self.writeClaudeSettings(settings)
    }

    private static func isNotchHubGroup(_ group: [String: Any]) -> Bool {
        let entries = group["hooks"] as? [[String: Any]] ?? []
        return entries.contains { ($0["command"] as? String)?.contains("notchhub-alert") == true }
    }

    private static func readClaudeSettings() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: claudeSettingsURL), !data.isEmpty else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return object
    }

    private static func writeClaudeSettings(_ settings: [String: Any]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: claudeSettingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: claudeSettingsURL.path) {
            let backup = claudeSettingsURL.appendingPathExtension("notchhub-backup")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: claudeSettingsURL, to: backup)
        }
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: claudeSettingsURL, options: .atomic)
    }
}
