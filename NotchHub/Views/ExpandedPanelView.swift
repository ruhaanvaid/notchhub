import SwiftUI

/// Expanded panel:
/// - header row in the band beside the notch: output picker (left), toggles (right)
/// - now playing
/// - volume
/// - file shelf, when it has items or a file is being dragged in
struct ExpandedPanelView: View {
    let state: NotchState
    let context: PanelContext
    let geometry: NotchGeometry
    private var settings: AppSettings { .shared }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                context: context,
                notchWidth: geometry.hasHardwareNotch ? geometry.notchSize.width : 0,
                height: geometry.notchSize.height
            )

            if settings.showNowPlaying || settings.showAudioControls {
                VStack(spacing: 14) {
                    if settings.showNowPlaying {
                        NowPlayingView(service: context.nowPlaying, openSettings: context.openSettings)
                    }
                    if settings.showAudioControls {
                        VolumeRow(volume: context.volume)
                    }
                }
                .padding(.top, 14)
            }

            Spacer(minLength: 0)

            if state.showsShelf {
                ShelfRowView(shelf: context.shelf, isTargeted: state.isDropTargeted)
                    .frame(height: NotchLayout.shelfRowHeight - 12)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(NotchStyle.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
