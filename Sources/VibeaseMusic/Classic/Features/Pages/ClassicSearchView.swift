// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI


struct ClassicSearchView: View {
    let query: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var model: SearchViewModel
    @Environment(PlayerService.self) private var player

    init(query: String) {
        self.query = query
        _model = State(initialValue: SearchViewModel(query: query))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 4) {
                    ForEach(SearchViewModel.Tab.allCases) { tab in
                        Button {
                            model.tab = tab
                        } label: {
                            Text(LocalizedStringKey(tab.rawValue))
                                .font(.system(size: 13, weight: model.tab == tab ? .semibold : .medium))
                                .foregroundStyle(model.tab == tab ? (colorScheme == .dark ? ClassicTheme.accent : ClassicTheme.accentDeep) : .primary)
                                .frame(width: 60, height: 32)
                                .background {
                                    if model.tab == tab {
                                        Capsule()
                                            .fill(ClassicTheme.accent.opacity(0.13))
                                            .overlay(Capsule().strokeBorder(ClassicTheme.accent.opacity(0.2), lineWidth: 0.5))
                                    }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                    }
                }
                .padding(5)
                .classicCompatGlass(interactive: true, in: Capsule())
                .accessibilityElement(children: .contain)
                .accessibilityLabel("搜索分类")
                .padding(.horizontal, ClassicTheme.Layout.contentInset)
                .padding(.top, 16)

                if model.isLoading, currentEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let errorMessage = model.errorMessage, currentEmpty {
                    ClassicErrorStateView(message: errorMessage) {
                        Task { await model.reloadCurrentTab() }
                    }
                    .frame(minHeight: 300)
                } else {
                    tabContent
                }
                Color.clear.frame(height: 8)
            }
        }
        .classicHoverScrollIndicators()
        .navigationTitle(String(localized: "搜索：\(query)"))
        .task(id: model.tab) {
            await model.load(tab: model.tab)
        }
    }

    private var currentEmpty: Bool {
        switch model.tab {
        case .all:
            return model.songs.isEmpty && model.artists.isEmpty
                && model.albums.isEmpty && model.playlists.isEmpty
        case .songs: return model.songs.isEmpty
        case .artists: return model.artists.isEmpty
        case .albums: return model.albums.isEmpty
        case .playlists: return model.playlists.isEmpty
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch model.tab {
        case .all:
            if !model.songs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ClassicSectionHeader(title: "单曲") {
                        model.tab = .songs
                    }
                    .padding(.horizontal, ClassicTheme.Layout.contentInset)
                    ClassicTrackListView(tracks: Array(model.songs.prefix(6)))
                        .padding(.horizontal, ClassicTheme.Layout.contentInset - 10)
                }
            }
            if !model.artists.isEmpty {
                ClassicShelf(title: "歌手", seeAll: { model.tab = .artists }) {
                    artistCards(model.artists.prefix(8))
                }
            }
            if !model.albums.isEmpty {
                ClassicShelf(title: "专辑", seeAll: { model.tab = .albums }) {
                    albumCards(model.albums.prefix(8))
                }
            }
            if !model.playlists.isEmpty {
                ClassicShelf(title: "歌单", seeAll: { model.tab = .playlists }) {
                    playlistCards(model.playlists.prefix(8))
                }
            }
            if currentEmpty, !model.isLoading {
                ClassicEmptyStateView(icon: "magnifyingglass", title: "没有找到相关结果")
                    .frame(minHeight: 300)
            }
        case .songs:
            ClassicTrackListView(tracks: model.songs)
                .padding(.horizontal, ClassicTheme.Layout.contentInset - 10)
        case .artists:
            ClassicCardGrid(minWidth: 140) {
                artistCards(model.artists)
            }
            .padding(.horizontal, ClassicTheme.Layout.contentInset)
        case .albums:
            ClassicCardGrid {
                albumCards(model.albums)
            }
            .padding(.horizontal, ClassicTheme.Layout.contentInset)
        case .playlists:
            ClassicCardGrid {
                playlistCards(model.playlists)
            }
            .padding(.horizontal, ClassicTheme.Layout.contentInset)
        }
    }

    private func artistCards(_ items: some Collection<ArtistSummary>) -> some View {
        ForEach(Array(items)) { artist in
            NavigationLink(value: Destination.artist(artist.id)) {
                VStack(spacing: 10) {
                    CachedAsyncImage(url: artist.picUrl?.resizedImageURL(256))
                        .frame(width: 128, height: 128)
                        .clipShape(Circle())
                    Text(artist.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(width: 140)
                .contentShape(Rectangle())
            }
            .buttonStyle(.classicInteractiveCard)
        }
    }

    private func albumCards(_ items: some Collection<AlbumSummary>) -> some View {
        ForEach(Array(items)) { album in
            NavigationLink(value: Destination.album(album.id)) {
                ClassicCoverCardBody(
                    coverURL: album.picUrl?.resizedImageURL(384),
                    title: album.name,
                    subtitle: album.artistName
                )
            }
            .buttonStyle(.classicInteractiveCard)
        }
    }

    private func playlistCards(_ items: some Collection<PlaylistSummary>) -> some View {
        ForEach(Array(items)) { playlist in
            NavigationLink(value: Destination.playlist(playlist.id)) {
                ClassicCoverCardBody(
                    coverURL: playlist.coverURL?.resizedImageURL(384),
                    title: playlist.name,
                    playCount: playlist.playCount
                )
            }
            .buttonStyle(.classicInteractiveCard)
        }
    }
}
