import SwiftUI

struct MainWindow: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(SettingsManager.self) private var settings
    @Environment(ToastCenter.self) private var toasts

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: SidebarItem = .home
    @State private var path = NavigationPath()
    @State private var showLogin = false
    @State private var searchText = ""
    @State private var searchSuggestions: [SearchSuggestion] = []
    @State private var searchFocused = false
    @State private var selectedSuggestion = -1
    @State private var homeScrollRequest = 0

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection, showLogin: $showLogin) {
                selection = .home
                path = NavigationPath()
                homeScrollRequest += 1
            }
                .equatable()
                .navigationSplitViewColumnWidth(min: 200, ideal: Theme.Layout.sidebarWidth, max: 280)
                // Washi replaces the system sidebar toggle, whose Liquid Glass
                // bezel would be the only piece of glass on the paper.
                .toolbar(removing: Theme.isWashi ? .sidebarToggle : nil)
        } detail: {
            detailStack
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { PaperBackground().ignoresSafeArea() }
                .playerChrome()
        }
        .toolbar {
            if Theme.isWashi {
                if #available(macOS 26.0, *) {
                    ToolbarItem(placement: .navigation) {
                        SidebarToggleButton(columnVisibility: $columnVisibility)
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigation) {
                        SidebarToggleButton(columnVisibility: $columnVisibility)
                    }
                }
            }
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    SearchFieldView(text: $searchText, isFocused: $searchFocused,
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
                    SearchFieldView(text: $searchText, isFocused: $searchFocused,
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
            // Let the paper run up under the title bar instead of a grey strip.
            let background = Theme.windowBackground
            if window.backgroundColor !== background {
                window.backgroundColor = background
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
            var loaded = (result?.songs ?? []).prefix(3).map(SearchSuggestion.song)
                + (result?.artists ?? []).prefix(3).map(SearchSuggestion.artist)
                + (result?.albums ?? []).prefix(2).map(SearchSuggestion.album)
            if loaded.isEmpty {
                async let songs = try? NeteaseAPI.search(query, type: .songs, limit: 3)
                async let artists = try? NeteaseAPI.search(query, type: .artists, limit: 3)
                async let albums = try? NeteaseAPI.search(query, type: .albums, limit: 2)
                loaded = (await songs?.songs ?? []).map(SearchSuggestion.song)
                    + (await artists?.artists ?? []).map(SearchSuggestion.artist)
                    + (await albums?.albums ?? []).map(SearchSuggestion.album)
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
            LoginSheet()
        }
        .overlay {
            if player.showNowPlaying {
                NowPlayingView { destination in
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        player.showNowPlaying = false
                        path.append(destination)
                    }
                }
                .ignoresSafeArea()
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                ))
            }
        }
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast)
                    .transition(.asymmetric(
                        insertion: .offset(y: -14).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
                    .padding(.top, 12)
            }
        }
        .animation(AppAnimation.smooth, value: player.showNowPlaying)
        .animation(.spring(duration: 0.3), value: toasts.current)
    }

    private var detailStack: some View {
        NavigationStack(path: $path) {
            rootView
                .id(account.sessionVersion)
                .playerContentInset()
                .appDestinations()
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
            HomeView(scrollToTopRequest: homeScrollRequest)
        case .explore:
            ExploreView()
        case .fm:
            FMView()
        case .likedSongs:
            if let playlist = account.likedSongsPlaylist {
                PlaylistDetailView(playlistID: playlist.id, isLikedList: true)
                    .id(playlist.id)
            } else {
                loginPrompt
            }
        case .daily:
            DailySongsView()
        case .recents:
            RecentsView()
        case .collections:
            CollectionsView()
        case .cloud:
            CloudView()
        case .playlist(let id):
            PlaylistDetailView(playlistID: id)
                .id(id)
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 18) {
            ZStack {
                Enso(lineWidth: 5, color: Theme.ink.opacity(0.6))
                    .frame(width: 92, height: 92)
                SealStamp(text: "心", size: 30)
                    .rotationEffect(.degrees(-5))
            }
            Text("登录后查看你喜欢的音乐")
                .font(.serif(17, .bold))
                .foregroundStyle(Theme.ink)
            Button("登录") { showLogin = true }
                .buttonStyle(.ink)
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
                            .font(.system(size: 11))
                            .frame(width: 18)
                            .foregroundStyle(index == selectedSuggestion ? Theme.accent : Theme.ink.opacity(0.45))
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
                    .background(index == selectedSuggestion ? Theme.wash : .clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 240)
        .compatGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
    }

    private func selectSearchSuggestion(_ suggestion: SearchSuggestion) {
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

enum SearchSuggestion: Identifiable {
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

struct SearchFieldView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var selectedSuggestion: Int
    let suggestions: [SearchSuggestion]
    let onSubmit: (String) -> Void
    let onSelect: (SearchSuggestion) -> Void

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
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Theme.sheet.opacity(focused ? 1 : 0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(focused ? Theme.ink.opacity(0.35) : Theme.hairline, lineWidth: 0.75))
        .overlay(alignment: .bottom) {
            // A thin vermilion brush line paints under the field while typing.
            PaintedBrush(painted: focused, color: Theme.accent.opacity(0.7))
                .frame(height: 2.5)
                .padding(.horizontal, 16)
                .offset(y: 1)
        }
        .animation(AppAnimation.quick, value: focused)
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

// MARK: - Sidebar toggle

/// A bare ink glyph on the paper, with a faint wash on hover.
private struct SidebarToggleButton: View {
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @State private var isHovering = false

    private var isCollapsed: Bool { columnVisibility == .detailOnly }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                columnVisibility = isCollapsed ? .all : .detailOnly
            }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.ink.opacity(isHovering ? 0.9 : 0.6))
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
                        .fill(isHovering ? Theme.wash : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .focusEffectDisabled()
        .onHover { isHovering = $0 }
        .animation(AppAnimation.quick, value: isHovering)
        .help(isCollapsed ? "显示边栏" : "隐藏边栏")
        .accessibilityLabel(isCollapsed ? "显示边栏" : "隐藏边栏")
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
            Text(toast.message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .compatGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}
