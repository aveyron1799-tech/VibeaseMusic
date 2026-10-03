import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    enum Tab: String, CaseIterable, Identifiable {
        case all = "综合"
        case songs = "单曲"
        case artists = "歌手"
        case albums = "专辑"
        case playlists = "歌单"

        var id: String { rawValue }
    }

    let query: String
    var tab: Tab = .all
    var songs: [Track] = []
    var artists: [ArtistSummary] = []
    var albums: [AlbumSummary] = []
    var playlists: [PlaylistSummary] = []
    var isLoading = false
    var loadedTabs: Set<Tab> = []
    var errorMessage: String?

    init(query: String) {
        self.query = query
    }

    func load(tab: Tab) async {
        guard !loadedTabs.contains(tab) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch tab {
            case .all:
                async let songsTask = fetchSearch(type: .songs, limit: 12)
                async let artistsTask = fetchSearch(type: .artists, limit: 10)
                async let albumsTask = fetchSearch(type: .albums, limit: 10)
                async let playlistsTask = fetchSearch(type: .playlists, limit: 10)

                let results = await (songsTask, artistsTask, albumsTask, playlistsTask)
                var hasSuccessfulRequest = false
                var firstError: Error?

                switch results.0 {
                case .success(let result):
                    songs = result.songs ?? []
                    hasSuccessfulRequest = true
                case .failure(let error):
                    firstError = error
                }
                switch results.1 {
                case .success(let result):
                    artists = result.artists ?? []
                    hasSuccessfulRequest = true
                case .failure(let error):
                    firstError = firstError ?? error
                }
                switch results.2 {
                case .success(let result):
                    albums = result.albums ?? []
                    hasSuccessfulRequest = true
                case .failure(let error):
                    firstError = firstError ?? error
                }
                switch results.3 {
                case .success(let result):
                    playlists = result.playlists ?? []
                    hasSuccessfulRequest = true
                case .failure(let error):
                    firstError = firstError ?? error
                }

                if !hasSuccessfulRequest {
                    throw firstError ?? NeteaseAPIError.decoding("search")
                }
            case .songs:
                songs = try await NeteaseAPI.search(query, type: .songs, limit: 100).songs ?? []
            case .artists:
                artists = try await NeteaseAPI.search(query, type: .artists, limit: 50).artists ?? []
            case .albums:
                albums = try await NeteaseAPI.search(query, type: .albums, limit: 50).albums ?? []
            case .playlists:
                playlists = try await NeteaseAPI.search(query, type: .playlists, limit: 50).playlists ?? []
            }
            guard !Task.isCancelled else { return }
            loadedTabs.insert(tab)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    func reloadCurrentTab() async {
        loadedTabs.remove(tab)
        await load(tab: tab)
    }

    private func fetchSearch(
        type: NeteaseAPI.SearchType, limit: Int
    ) async -> Result<NeteaseAPI.SearchResult, Error> {
        do {
            return .success(try await NeteaseAPI.search(query, type: type, limit: limit))
        } catch {
            return .failure(error)
        }
    }
}

struct SearchView: View {
    let query: String

    @State private var model: SearchViewModel
    @Environment(PlayerService.self) private var player

    init(query: String) {
        self.query = query
        _model = State(initialValue: SearchViewModel(query: query))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    PageMasthead(title: Text(verbatim: query), caption: Text("搜索"))
                    HStack(spacing: 22) {
                        ForEach(SearchViewModel.Tab.allCases) { tab in
                            SearchTabButton(title: LocalizedStringKey(tab.rawValue),
                                            isSelected: model.tab == tab) {
                                model.tab = tab
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("搜索分类")
                    .padding(.bottom, 2)
                    .background(alignment: .bottom) {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 0.75)
                    }
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 14)

                if model.isLoading, currentEmpty {
                    InkLoader()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let errorMessage = model.errorMessage, currentEmpty {
                    ErrorStateView(message: errorMessage) {
                        Task { await model.reloadCurrentTab() }
                    }
                    .frame(minHeight: 300)
                } else {
                    tabContent
                }
                Color.clear.frame(height: 8)
            }
        }
        .hoverScrollIndicators()
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
                    SectionHeader(title: "单曲") {
                        model.tab = .songs
                    }
                    .padding(.horizontal, Theme.Layout.contentInset)
                    TrackListView(tracks: Array(model.songs.prefix(6)))
                        .padding(.horizontal, Theme.Layout.contentInset - 10)
                }
            }
            if !model.artists.isEmpty {
                Shelf(title: "歌手", seeAll: { model.tab = .artists }) {
                    artistCards(model.artists.prefix(8))
                }
            }
            if !model.albums.isEmpty {
                Shelf(title: "专辑", seeAll: { model.tab = .albums }) {
                    albumCards(model.albums.prefix(8))
                }
            }
            if !model.playlists.isEmpty {
                Shelf(title: "歌单", seeAll: { model.tab = .playlists }) {
                    playlistCards(model.playlists.prefix(8))
                }
            }
            if currentEmpty, !model.isLoading {
                EmptyStateView(icon: "magnifyingglass", title: "没有找到相关结果")
                    .frame(minHeight: 300)
            }
        case .songs:
            TrackListView(tracks: model.songs)
                .padding(.horizontal, Theme.Layout.contentInset - 10)
        case .artists:
            CardGrid(minWidth: 148) {
                artistCards(model.artists)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
        case .albums:
            CardGrid {
                albumCards(model.albums)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
        case .playlists:
            CardGrid {
                playlistCards(model.playlists)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
        }
    }

    private func artistCards(_ items: some Collection<ArtistSummary>) -> some View {
        ForEach(Array(items)) { artist in
            NavigationLink(value: Destination.artist(artist.id)) {
                ArtistPortrait(url: artist.picUrl?.resizedImageURL(256), name: artist.name, size: 128)
            }
            .buttonStyle(.interactiveCard)
        }
    }

    private func albumCards(_ items: some Collection<AlbumSummary>) -> some View {
        ForEach(Array(items)) { album in
            NavigationLink(value: Destination.album(album.id)) {
                CoverCardBody(
                    coverURL: album.picUrl?.resizedImageURL(384),
                    title: album.name,
                    subtitle: album.artistName
                )
            }
            .buttonStyle(.interactiveCard)
        }
    }

    private func playlistCards(_ items: some Collection<PlaylistSummary>) -> some View {
        ForEach(Array(items)) { playlist in
            NavigationLink(value: Destination.playlist(playlist.id)) {
                CoverCardBody(
                    coverURL: playlist.coverURL?.resizedImageURL(384),
                    title: playlist.name,
                    playCount: playlist.playCount
                )
            }
            .buttonStyle(.interactiveCard)
        }
    }
}

/// A bare word that darkens when chosen, with a vermilion brush stroke
/// painting in beneath it.
private struct SearchTabButton: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(Theme.ink.opacity(isSelected ? 1 : (isHovering ? 0.8 : 0.55)))
                .padding(.vertical, 8)
                .background(alignment: .bottom) {
                    PaintedBrush(painted: isSelected, color: Theme.accent.opacity(0.85))
                        .frame(height: 4)
                        .padding(.horizontal, -3)
                        .offset(y: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(AppAnimation.quick, value: isHovering)
        .animation(AppAnimation.spring, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
