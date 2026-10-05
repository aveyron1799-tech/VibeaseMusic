// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI


struct ClassicPlayerChromeModifier: ViewModifier {
    @Environment(PlayerService.self) private var player

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ClassicPlayerBar()
            }
            .overlay(alignment: .trailing) {
                rightPanel
            }
            .animation(ClassicAnimation.standard, value: player.activePanel)
    }

    @ViewBuilder
    private var rightPanel: some View {
        if let panel = player.activePanel {
            Group {
                switch panel {
                case .lyrics:
                    ClassicLyricsPanel()
                case .queue:
                    ClassicQueuePanel()
                }
            }
            .padding(.top, 12)
            .padding(.bottom, ClassicTheme.Layout.playerBarHeight + 20)
            .padding(.trailing, 16)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}



/// Registers all shared navigation destinations on a stack.
struct ClassicDestinationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Destination.self) { destination in
            Group {
                switch destination {
                case .playlist(let id):
                    ClassicPlaylistDetailView(playlistID: id)
                case .album(let id):
                    ClassicAlbumDetailView(albumID: id)
                case .artist(let id):
                    ClassicArtistDetailView(artistID: id)
                case .artistAlbums(let id, let name):
                    ClassicArtistAlbumsView(artistID: id, artistName: name)
                case .daily:
                    ClassicDailySongsView()
                case .toplists:
                    ClassicToplistsView()
                case .search(let query):
                    ClassicSearchView(query: query)
                }
            }
            .classicPlayerContentInset()
            .background(Color(nsColor: .windowBackgroundColor))
            // Pushed pages are layered above the detail column's own overlay,
            // so each one carries its chrome or the player bar disappears.
            .classicPlayerChrome()
        }
    }
}

extension View {
    func classicPlayerChrome() -> some View {
        modifier(ClassicPlayerChromeModifier())
    }

    func classicPlayerContentInset() -> some View {
        safeAreaPadding(.bottom, ClassicTheme.Layout.playerBarHeight + 10)
    }

    func classicAppDestinations() -> some View {
        modifier(ClassicDestinationsModifier())
    }
}
