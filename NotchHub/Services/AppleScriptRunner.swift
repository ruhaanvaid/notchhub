import Foundation

/// Runs AppleScript off the main thread. The first script sent to an app can show a
/// system Automation prompt and block until the user answers, so this must never run
/// on the main thread. All scripts run on one serial queue and are compiled once.
final class AppleScriptRunner: @unchecked Sendable {
    enum Output: Sendable {
        case success(string: String?, data: Data?)
        case failure(code: Int, message: String)
    }

    /// The user denied NotchHub control of the target app (System Settings › Automation).
    static let notPermittedError = -1743
    /// The target app isn't running.
    static let appNotRunningError = -600

    private let queue = DispatchQueue(label: "com.notchhub.applescript", qos: .userInitiated)
    /// Only touched on `queue`.
    private var compiled: [String: NSAppleScript] = [:]

    func run(_ source: String) async -> Output {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.execute(source))
            }
        }
    }

    private func execute(_ source: String) -> Output {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let created = NSAppleScript(source: source) else {
                return .failure(code: 0, message: "Couldn't create script")
            }
            var compileError: NSDictionary?
            guard created.compileAndReturnError(&compileError) else {
                return Self.failure(from: compileError)
            }
            compiled[source] = created
            script = created
        }

        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            return Self.failure(from: error)
        }
        let data = descriptor.data
        return .success(string: descriptor.stringValue, data: data.isEmpty ? nil : data)
    }

    private static func failure(from error: NSDictionary?) -> Output {
        let code = (error?[NSAppleScript.errorNumber] as? Int) ?? 0
        let message = (error?[NSAppleScript.errorMessage] as? String) ?? "AppleScript error \(code)"
        return .failure(code: code, message: message)
    }
}
