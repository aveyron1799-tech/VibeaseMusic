// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI


struct ClassicHomeView: View {
    let scrollToTopRequest: Int
    @Environment(AccountStore.self) private var account
    @Environment(PlayerService.self) private var player
    @Environment(\.openLogin) private var openLogin
    @State private var model = HomeViewModel.shared

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 1).id("home-top")
                    switch model.state {
                    case .idle, .loading:
                        loadingBody
                    case .error(let message):
                        ClassicErrorStateView(message: message) {
                            Task {
                                await model.reload(
                                    loggedIn: account.isLoggedIn, userID: account.profile?.userId
                                )
                            }
                        }
                        .frame(minHeight: 400)
                    case .loaded:
                        loadedBody
                    }
                }
            }
            .classicHoverScrollIndicators()
            .onChange(of: scrollToTopRequest) {
                withAnimation(ClassicAnimation.smooth) {
                    scrollProxy.scrollTo("home-top", anchor: .top)
                }
            }
        }
        .navigationTitle("推荐")
        .task(id: "\(account.sessionVersion)-\(account.profile?.userId ?? 0)-\(account.isLoggedIn)") {
            await model.load(loggedIn: account.isLoggedIn, userID: account.profile?.userId)
        }
    }

    private var loadingBody: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    ClassicSkeletonView(cornerRadius: ClassicTheme.Radius.large)
                        .frame(width: 230, height: 132)
                }
            }
            ClassicSkeletonShelf()
            ClassicSkeletonShelf()
        }
        .padding(ClassicTheme.Layout.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadedBody: some View {
        LazyVStack(alignment: .leading, spacing: 34) {
            featureCards
                .padding(.top, 8)

            if !model.recommendPlaylists.isEmpty {
                ClassicShelf(title: "推荐歌单") {
                    ForEach(Array(model.recommendPlaylists.prefix(12).enumerated()), id: \.element.id) { index, playlist in
                        playlistCard(playlist)
                            .classicStaggeredAppearance(index: index, id: "home-rec-\(playlist.id)")
                    }
                }
            }

            if !model.radarPlaylists.isEmpty {
                ClassicShelf(title: "雷达歌单") {
                    ForEach(model.radarPlaylists) { radar in
                        ClassicNavigationCoverCard(
                            destination: .playlist(radar.id),
                            coverURL: radar.coverURL?.resizedImageURL(384),
                            title: radar.title,
                            subtitle: radar.subtitle,
                            onPlay: { playPlaylist(radar.id) }
                        )
                    }
                }
            }

            if !model.toplists.isEmpty {
                ClassicShelf(title: "排行榜", seeAll: nil) {
                    ForEach(model.toplists) { toplist in
                        NavigationLink(value: Destination.playlist(toplist.id)) {
                            toplistCard(toplist)
                        }
                        .buttonStyle(.classicInteractiveCard)
                    }
                }
            }

            if !model.newAlbums.isEmpty {
                ClassicShelf(title: "新碟上架") {
                    ForEach(model.newAlbums) { album in
                        albumCard(album)
                    }
                }
            }

            if !model.topArtists.isEmpty {
                ClassicShelf(title: "推荐歌手") {
                    ForEach(model.topArtists) { artist in
                        artistCard(artist)
                    }
                }
            }

            Color.clear.frame(height: 8)
        }
        .padding(.vertical, ClassicTheme.Layout.contentInset - 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Feature cards

    @ViewBuilder
    private var featureCards: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { featureCardRow }
        } else {
            featureCardRow
        }
    }

    private var featureCardRow: some View {
            HStack(spacing: 16) {
                if account.isLoggedIn {
                    NavigationLink(value: Destination.daily) {
                        ClassicFeatureCard(
                            title: "每日推荐",
                            subtitle: "根据你的口味生成",
                            icon: "calendar",
                            coverURL: model.dailyFirstCover?.resizedImageURL(512),
                            showsDate: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        player.startFM()
                    } label: {
                        ClassicFeatureCard(
                            title: "私人漫游",
                            subtitle: "从喜欢的歌开始漫游",
                            icon: "wave.3.right.circle.fill",
                            gradient: [Color(red: 0.16, green: 0.20, blue: 0.42),
                                       Color(red: 0.36, green: 0.24, blue: 0.62)]
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        startHeartbeatMode()
                    } label: {
                        ClassicFeatureCard(
                            title: "心动模式",
                            subtitle: "你的红心歌曲和相似推荐",
                            icon: "heart.circle.fill",
                            gradient: [Color(red: 0.85, green: 0.19, blue: 0.41),
                                       Color(red: 0.98, green: 0.42, blue: 0.34)]
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        openLogin()
                    } label: {
                        ClassicFeatureCard(
                            title: "登录网易云音乐",
                            subtitle: "解锁每日推荐、私人漫游与心动模式",
                            icon: "person.crop.circle.badge.checkmark",
                            gradient: [ClassicTheme.accentDeep, ClassicTheme.accent]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ClassicTheme.Layout.contentInset)
            .padding(.vertical, 6)
    }

    private func startHeartbeatMode() {
        guard let likedList = account.likedSongsPlaylist else { return }
        Task {
            guard let seed = account.likedTrackIDs.randomElement() else {
                ToastCenter.shared.show(String(localized: "先收藏一些喜欢的歌曲吧"))
                return
            }
            do {
                let tracks = try await NeteaseAPI.intelligenceList(songID: seed, playlistID: likedList.id)
                guard !tracks.isEmpty else {
                    ToastCenter.shared.show(String(localized: "心动模式暂时不可用"))
                    return
                }
                player.play(tracks: tracks, source: .playlist(likedList.id))
                ToastCenter.shared.show(String(localized: "已开启心动模式"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    // MARK: - Cards

    private func playlistCard(_ playlist: PlaylistSummary) -> some View {
        ClassicNavigationCoverCard(
            destination: .playlist(playlist.id),
            coverURL: playlist.coverURL?.resizedImageURL(384),
            title: playlist.name,
            subtitle: playlist.copywriter,
            playCount: playlist.playCount,
            onPlay: { playPlaylist(playlist.id) }
        )
    }

    private func albumCard(_ album: AlbumSummary) -> some View {
        ClassicNavigationCoverCard(
            destination: .album(album.id),
            coverURL: album.picUrl?.resizedImageURL(384),
            title: album.name,
            subtitle: album.artistName,
            onPlay: {
                Task {
                    if let detail = try? await NeteaseAPI.album(id: album.id) {
                        player.play(tracks: detail.songs, source: .album(album.id))
                    }
                }
            }
        )
    }

    private func artistCard(_ artist: ArtistSummary) -> some View {
        NavigationLink(value: Destination.artist(artist.id)) {
            VStack(spacing: 10) {
                CachedAsyncImage(url: artist.picUrl?.resizedImageURL(256))
                    .frame(width: 128, height: 128)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
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

    private func toplistCard(_ toplist: ToplistItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: toplist.coverImgUrl?.resizedImageURL(384))
                    .frame(width: ClassicTheme.Layout.cardSize, height: ClassicTheme.Layout.cardSize)
                    .clipShape(RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous))
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous))
                Text(toplist.updateFrequency ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(8)
            }
            .frame(width: ClassicTheme.Layout.cardSize, height: ClassicTheme.Layout.cardSize)
            Text(toplist.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: ClassicTheme.Layout.cardSize, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func playPlaylist(_ id: Int) {
        Task {
            guard let detail = try? await NeteaseAPI.playlistDetail(id: id) else { return }
            var tracks = detail.playlist.tracks
            if tracks.count < detail.playlist.trackCount {
                let ids = detail.playlist.trackIds.map(\.id)
                if let full = try? await NeteaseAPI.songDetails(ids: Array(ids.prefix(1000))),
                   !full.songs.isEmpty {
                    tracks = full.songs
                }
            }
            player.play(tracks: tracks, source: .playlist(id))
        }
    }
}

// MARK: - Feature card

struct ClassicFeatureCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    var coverURL: URL?
    var gradient: [Color] = [Color(red: 0.75, green: 0.16, blue: 0.22),
                             Color(red: 0.95, green: 0.35, blue: 0.28)]
    var showsDate = false

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Group {
                    if showsDate {
                        VStack(spacing: 1) {
                            Text("今日").font(.system(size: 9, weight: .medium))
                            Text("\(Calendar.current.component(.day, from: .now))")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        }
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 25, weight: .medium))
                    }
                }
                .foregroundStyle(gradient[0])
                .frame(width: 46, height: 46)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                if let coverURL {
                    CachedAsyncImage(url: coverURL)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .rotationEffect(.degrees(isHovering && !reduceMotion ? 0 : 7))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: showsDate ? "calendar" : icon)
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(gradient[1].opacity(isHovering ? 0.22 : 0.12))
                        .rotationEffect(.degrees(isHovering && !reduceMotion ? -8 : 0))
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 12)
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(isHovering ? 0.85 : 0.4))
                    .offset(x: isHovering && !reduceMotion ? 2 : 0,
                            y: isHovering && !reduceMotion ? -2 : 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 166)
        .background {
            LinearGradient(colors: [gradient[0].opacity(0.15), gradient[1].opacity(isHovering ? 0.28 : 0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .classicCompatGlass(interactive: true, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: gradient[0].opacity(isHovering ? 0.13 : 0.03), radius: isHovering ? 10 : 3, y: 4)
        .offset(y: isHovering && !reduceMotion ? -3 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isHovering)
    }
}

/// Card body without its own Button wrapper (for use inside NavigationLink).
struct ClassicCoverCardBody: View {
    let coverURL: URL?
    let title: String
    var subtitle: String?
    var playCount: Int = 0
    var size: CGFloat = ClassicTheme.Layout.cardSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: coverURL)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                    )
                if playCount > 0 {
                    ClassicPlayCountBadge(count: playCount)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: size, height: size)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .frame(maxWidth: size, alignment: .leading)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: size, alignment: .leading)
            }
        }
        .frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
    }
}
