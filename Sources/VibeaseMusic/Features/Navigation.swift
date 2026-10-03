import SwiftUI

extension EnvironmentValues {
    @Entry var openLogin: () -> Void = {}
}

struct PlayerChromeModifier: ViewModifier {
    @Environment(PlayerService.self) private var player

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                PlayerBar()
            }
            .overlay(alignment: .trailing) {
                rightPanel
            }
            .animation(AppAnimation.standard, value: player.activePanel)
    }

    @ViewBuilder
    private var rightPanel: some View {
        if let panel = player.activePanel {
            Group {
                switch panel {
                case .lyrics:
                    LyricsPanel()
                case .queue:
                    QueuePanel()
                }
            }
            .padding(.top, 12)
            .padding(.bottom, Theme.Layout.playerBarHeight + 24)
            .padding(.trailing, 18)
            .transition(.offset(x: 40).combined(with: .opacity))
        }
    }
}

enum SidebarItem: Hashable {
    case home
    case explore
    case fm
    case likedSongs
    case daily
    case recents
    case collections
    case cloud
    case playlist(Int)
}

enum Destination: Hashable {
    case playlist(Int)
    case album(Int)
    case artist(Int)
    case artistAlbums(Int, String)
    case daily
    case toplists
    case search(String)
}

/// Registers all shared navigation destinations on a stack.
struct DestinationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: Destination.self) { destination in
            Group {
                switch destination {
                case .playlist(let id):
                    PlaylistDetailView(playlistID: id)
                case .album(let id):
                    AlbumDetailView(albumID: id)
                case .artist(let id):
                    ArtistDetailView(artistID: id)
                case .artistAlbums(let id, let name):
                    ArtistAlbumsView(artistID: id, artistName: name)
                case .daily:
                    DailySongsView()
                case .toplists:
                    ToplistsView()
                case .search(let query):
                    SearchView(query: query)
                }
            }
            .playerContentInset()
            .background { PaperBackground().ignoresSafeArea() }
        }
    }
}

extension View {
    func playerChrome() -> some View {
        modifier(PlayerChromeModifier())
    }

    func playerContentInset() -> some View {
        safeAreaPadding(.bottom, Theme.Layout.playerBarHeight + 10)
    }

    func appDestinations() -> some View {
        modifier(DestinationsModifier())
    }
}
