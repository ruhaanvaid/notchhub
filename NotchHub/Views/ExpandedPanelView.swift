import SwiftUI

/// Expanded panel:
/// - header row in the band beside the notch: output picker (left), toggles (right)
/// - now playing, or the timer page (wheels / countdown) from the header's timer button
/// - file shelf, when it has items or a file is being dragged in
struct ExpandedPanelView: View {
    let state: NotchState
    let context: PanelContext
    let geometry: NotchGeometry
    private var settings: AppSettings { .shared }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                state: state,
                context: context,
                notchWidth: geometry.hasHardwareNotch ? geometry.notchSize.width : 0,
                height: geometry.notchSize.height
            )

            // Volume isn't shown here: it pops up from the notch when you press the volume keys.
            if state.page == .timer {
                TimerPageView(timer: context.timer) { state.page = .main }
                    .padding(.top, 8)
                    .transition(.opacity)
            } else if settings.showNowPlaying {
                VStack(spacing: 6) {
                    NowPlayingView(service: context.nowPlaying, openSettings: context.openSettings)
                    TrackProgressView(service: context.nowPlaying)
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
