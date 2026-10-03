// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI

struct ClassicMainWindow: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(SettingsManager.self) private var settings
    @Environment(ToastCenter.self) private var toasts

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: SidebarItem = .home
    @State private var path = NavigationPath()
    @State private var showLogin = false
    @State private var searchText = ""
    @State private var searchSuggestions: [ClassicSearchSuggestion] = []
    @State private var searchFocused = false
    @State private var selectedSuggestion = -1
    @State private var homeScrollRequest = 0

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ClassicSidebarView(selection: $selection, showLogin: $showLogin) {
                selection = .home
                path = NavigationPath()
                homeScrollRequest += 1
            }
                .equatable()
                .navigationSplitViewColumnWidth(min: 200, ideal: ClassicTheme.Layout.sidebarWidth, max: 280)
        } detail: {
            detailStack
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .classicPlayerChrome()
        }
        .toolbar {
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    ClassicSearchFieldView(text: $searchText, isFocused: $searchFocused,
                                    selectedSuggestion: $selectedSuggestion,
                                    suggestions: searchSuggestions,
                                    onSubmit: {
                                        searchSuggestions = []
                                        searchFocused = false
                                        path.append(Destination.search($0))
                                    },
                                    onSelect: selectSearchSuggestion)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) {
                    ClassicSearchFieldView(text: $searchText, isFocused: $searchFocused,
                                    selectedSuggestion: $selectedSuggestion,
                                    suggestions: searchSuggestions,
                                    onSubmit: {
                                        searchSuggestions = []
                                        searchFocused = false
                                        path.append(Destination.search($0))
                                    },
                                    onSelect: selectSearchSuggestion)
                }
            }
        }
        // Immersive now-playing page: hide the whole window toolbar
        // (sidebar toggle, navigation title, search field).
        .toolbar(player.showNowPlaying ? .hidden : .automatic, for: .windowToolbar)
        .toolbarBackground(player.showNowPlaying ? .hidden : .automatic, for: .windowToolbar)
        .background(WindowAccessor { window in
            if window.backgroundColor != .windowBackgroundColor {
                window.backgroundColor = .windowBackgroundColor
            }
        })
        .overlay(alignment: .topTrailing) {
            if !searchSuggestions.isEmpty && !player.showNowPlaying {
                searchSuggestionsPanel
                    .padding(.top, 0)
                    .padding(.trailing, 24)
                    .transition(.opacity)
            }
        }
        .task(id: searchText) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                searchSuggestions = []
                return
            }
            searchSuggestions = [.query(query)]
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, searchFocused else { return }
            let result = try? await NeteaseAPI.searchSuggest(query)
            guard !Task.isCancelled, searchFocused else { return }
            var loaded = (result?.songs ?? []).prefix(3).map(ClassicSearchSuggestion.song)
                + (result?.artists ?? []).prefix(3).map(ClassicSearchSuggestion.artist)
                + (result?.albums ?? []).prefix(2).map(ClassicSearchSuggestion.album)
            if loaded.isEmpty {
                async let songs = try? NeteaseAPI.search(query, type: .songs, limit: 3)
                async let artists = try? NeteaseAPI.search(query, type: .artists, limit: 3)
                async let albums = try? NeteaseAPI.search(query, type: .albums, limit: 2)
                loaded = (await songs?.songs ?? []).map(ClassicSearchSuggestion.song)
                    + (await artists?.artists ?? []).map(ClassicSearchSuggestion.artist)
                    + (await albums?.albums ?? []).map(ClassicSearchSuggestion.album)
            }
            guard !Task.isCancelled, searchFocused else { return }
            searchSuggestions = [.query(query)] + loaded
            selectedSuggestion = -1
        }
        .onChange(of: searchFocused) {
            if !searchFocused { searchSuggestions = [] }
        }
        .onChange(of: selection) {
            searchSuggestions = []
        }
        .environment(\.openLogin, { showLogin = true })
        .task {
            DesktopLyricsController.shared.sync(with: settings.showDesktopLyrics)
            await account.bootstrap()
        }
        .onChange(of: settings.showDesktopLyrics) {
            DesktopLyricsController.shared.sync(with: settings.showDesktopLyrics)
        }
        .sheet(isPresented: $showLogin) {
            ClassicLoginSheet()
        }
        .overlay {
            if player.showNowPlaying {
                ClassicNowPlayingView { destination in
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        player.showNowPlaying = false
                        path.append(destination)
                    }
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ClassicToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
        .animation(ClassicAnimation.smooth, value: player.showNowPlaying)
        .animation(.spring(duration: 0.3), value: toasts.current)
    }

    private var detailStack: some View {
        NavigationStack(path: $path) {
            rootView
                .id(account.sessionVersion)
                .classicPlayerContentInset()
                .classicAppDestinations()
        }
        .onChange(of: selection) {
            path = NavigationPath()
        }
        .onChange(of: account.sessionVersion) {
            // Discard detail routes belonging to the previous account too.
            path = NavigationPath()
            selection = .home
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            searchFocused = false
        })
    }

    @ViewBuilder
    private var rootView: some View {
        switch selection {
        case .home:
            ClassicHomeView(scrollToTopRequest: homeScrollRequest)
        case .explore:
            ClassicExploreView()
        case .fm:
            ClassicFMView()
        case .likedSongs:
            if let playlist = account.likedSongsPlaylist {
                ClassicPlaylistDetailView(playlistID: playlist.id, isLikedList: true)
                    .id(playlist.id)
            } else {
                loginPrompt
            }
        case .daily:
            ClassicDailySongsView()
        case .recents:
            ClassicRecentsView()
        case .collections:
            ClassicCollectionsView()
        case .cloud:
            ClassicCloudView()
        case .playlist(let id):
            ClassicPlaylistDetailView(playlistID: id)
                .id(id)
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("登录后查看你喜欢的音乐")
                .font(.headline)
            Button("登录") { showLogin = true }
                .buttonStyle(.borderedProminent)
                .tint(ClassicTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchSuggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(searchSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    selectSearchSuggestion(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.icon)
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title).lineLimit(1)
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(index == selectedSuggestion ? ClassicTheme.accent.opacity(0.12) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 230)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
    }

    private func selectSearchSuggestion(_ suggestion: ClassicSearchSuggestion) {
        searchFocused = false
        searchSuggestions = []
        switch suggestion {
        case .query(let query): path.append(Destination.search(query))
        case .song(let track): player.playTrack(track)
        case .artist(let artist): path.append(Destination.artist(artist.id))
        case .album(let album): path.append(Destination.album(album.id))
        }
    }

}

// MARK: - Search field

enum ClassicSearchSuggestion: Identifiable {
    case query(String), song(Track), artist(ArtistSummary), album(AlbumSummary)

    var id: String {
        switch self {
        case .query(let query): return "query-\(query)"
        case .song(let track): return "song-\(track.id)"
        case .artist(let artist): return "artist-\(artist.id)"
        case .album(let album): return "album-\(album.id)"
        }
    }
    var title: String {
        switch self {
        case .query(let query): return "搜索“\(query)”"
        case .song(let track): return track.name
        case .artist(let artist): return artist.name
        case .album(let album): return album.name
        }
    }
    var subtitle: String {
        switch self {
        case .query: return "查看全部结果"
        case .song(let track): return "歌曲 · \(track.artistNames)"
        case .artist: return "歌手"
        case .album(let album): return "专辑 · \(album.artistName)"
        }
    }
    var icon: String {
        switch self {
        case .query: return "magnifyingglass"
        case .song: return "music.note"
        case .artist: return "person.fill"
        case .album: return "square.stack.fill"
        }
    }
}

struct ClassicSearchFieldView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var selectedSuggestion: Int
    let suggestions: [ClassicSearchSuggestion]
    let onSubmit: (String) -> Void
    let onSelect: (ClassicSearchSuggestion) -> Void

    @State private var placeholder = "搜索音乐、歌手、专辑"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($focused)
                .frame(width: 190)
                .onKeyPress(.downArrow) {
                    guard isFocused, !suggestions.isEmpty else { return .ignored }
                    selectedSuggestion = min(selectedSuggestion + 1, suggestions.count - 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard isFocused, !suggestions.isEmpty else { return .ignored }
                    selectedSuggestion = max(selectedSuggestion - 1, 0)
                    return .handled
                }
                .onKeyPress(.escape) {
                    isFocused = false
                    return .handled
                }
                .onSubmit {
                    if isFocused, suggestions.indices.contains(selectedSuggestion) {
                        onSelect(suggestions[selectedSuggestion])
                        return
                    }
                    let query = text.trimmingCharacters(in: .whitespaces)
                    let effective = query.isEmpty ? placeholderQuery : query
                    guard !effective.isEmpty else { return }
                    onSubmit(effective)
                    isFocused = false
                    focused = false
                }
                .onChange(of: focused) { isFocused = focused }
                .onChange(of: text) { isFocused = true }
                .onChange(of: isFocused) { if !isFocused { focused = false } }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(focused ? 0.18 : 0.08), lineWidth: 1))
        .animation(ClassicAnimation.quick, value: focused)
        .padding(.trailing, 16)
        .task {
            if let keyword = try? await NeteaseAPI.searchDefaultKeyword(), !keyword.isEmpty {
                placeholder = keyword
                placeholderQuery = keyword
            }
        }
    }

    @State private var placeholderQuery = ""

}

// MARK: - Toast

struct ClassicToastView: View {
    let toast: Toast

    var body: some View {
        Text(toast.message)
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .classicCompatGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
