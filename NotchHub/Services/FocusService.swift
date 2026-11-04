import AppKit
import Observation

/// Do Not Disturb via two user-created Shortcuts, run with `/usr/bin/shortcuts`.
/// There's no public API to set Focus, and no way to read its state without Full Disk
/// Access, so `isOn` is NotchHub's own record of what it last asked for.
@Observable
@MainActor
final class FocusService {
    static let onShortcutName = "NotchHub Focus On"
    static let offShortcutName = "NotchHub Focus Off"

    enum SetupState: Equatable {
        case unknown
        case ready
        /// Lists the shortcut names that weren't found.
        case missing([String])
    }

    private(set) var isOn = false
    private(set) var setupState: SetupState = .unknown
    private(set) var isBusy = false
    private(set) var lastError: String?

    var isReady: Bool { setupState == .ready }

    private static let shortcutsTool = "/usr/bin/shortcuts"

    /// Checks that both shortcuts exist.
    func checkSetup() {
        Task {
            let result = await Self.run(Self.shortcutsTool, ["list"])
            guard result.status == 0 else {
                setupState = .missing([Self.onShortcutName, Self.offShortcutName])
                lastError = result.errorText
                return
            }
            let names = Set(result.output.split(whereSeparator: \.isNewline).map {
                $0.trimmingCharacters(in: .whitespaces)
            })
            let missing = [Self.onShortcutName, Self.offShortcutName].filter { !names.contains($0) }
            setupState = missing.isEmpty ? .ready : .missing(missing)
        }
    }

    func toggle() {
        setFocus(!isOn)
    }

    func setFocus(_ on: Bool) {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        let name = on ? Self.onShortcutName : Self.offShortcutName
        Task {
            let result = await Self.run(Self.shortcutsTool, ["run", name])
            isBusy = false
            if result.status == 0 {
                isOn = on
            } else {
                lastError = result.errorText.isEmpty ? "Shortcut “\(name)” failed." : result.errorText
                checkSetup()
            }
        }
    }

    func openShortcutsApp() {
        if let url = URL(string: "shortcuts://create-shortcut") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Process

    private struct ProcessResult: Sendable {
        var status: Int32
        var output: String
        var errorText: String
    }

    /// Runs a tool off the main thread and collects its output.
    private nonisolated static func run(_ path: String, _ arguments: [String]) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ProcessResult(
                        status: -1, output: "", errorText: error.localizedDescription
                    ))
                    return
                }
                // Read before waiting so a large output can't fill the pipe and deadlock.
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: ProcessResult(
                    status: process.terminationStatus,
                    output: String(decoding: outData, as: UTF8.self),
                    errorText: String(decoding: errData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
        }
    }
}
