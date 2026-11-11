import AppKit
import Darwin
import IOKit.pwr_mgt

/// Which browsers are playing media right now, from the power assertions they hold while
/// playing ("Playing audio", "Playing video", WebKit's media playback). Reading assertions is
/// public IOKit API and needs no permission, unlike CoreAudio's per-process running state,
/// which macOS hides from other apps. Used to tell when a browser tab is actually playing,
/// which AppleScript alone can't reveal.
enum AudioActivity {
    static func playingBrowsers() -> Set<MediaPlayer> {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let table = byProcess?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return [] }

        let running = MediaPlayer.allCases.filter { $0.isBrowser && $0.isRunning }
        guard !running.isEmpty else { return [] }
        // Bundle names like "Google Chrome.app": Chrome may run from a private clone of its
        // bundle (…/code_sign_clone/…/Google Chrome.app.bundle/…), so match names, not paths.
        let bundleNames: [(MediaPlayer, String)] = running.compactMap { browser in
            NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleIdentifier)
                .first?.bundleURL.map { (browser, "/" + $0.lastPathComponent) }
        }

        var playing: Set<MediaPlayer> = []
        for (pid, assertions) in table where assertions.contains(where: isMediaAssertion) {
            let pid = pid.int32Value
            // The browser's own process (Chrome holds "Playing audio" in its main process).
            if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
               let browser = running.first(where: { $0.bundleIdentifier == bundleID }) {
                playing.insert(browser)
                continue
            }
            // A helper process, identified by its path.
            guard let path = executablePath(of: pid) else { continue }
            for (browser, name) in bundleNames where path.contains(name) {
                playing.insert(browser)
            }
            // Safari plays media from WebKit's shared processes, outside Safari.app.
            if path.contains("/WebKit.framework/"), running.contains(.safari) {
                playing.insert(.safari)
            }
        }
        return playing
    }

    private static func isMediaAssertion(_ assertion: [String: Any]) -> Bool {
        let name = (assertion[kIOPMAssertionNameKey] as? String ?? "").lowercased()
        return name.contains("playing audio") || name.contains("playing video") || name.contains("media playback")
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
