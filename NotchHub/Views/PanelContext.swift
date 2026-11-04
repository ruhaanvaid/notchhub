import Foundation

/// Everything the expanded panel's views need, passed down from `AppDelegate`.
@MainActor
struct PanelContext {
    let nowPlaying: NowPlayingService
    let volume: VolumeService
    let outputs: AudioOutputService
    let power: PowerService
    let focus: FocusService
    let shelf: ShelfStore
    let openSettings: () -> Void
}
