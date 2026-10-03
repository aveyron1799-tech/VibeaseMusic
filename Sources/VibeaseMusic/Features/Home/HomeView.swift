import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    /// Shared so the loaded page survives sidebar switches (no skeleton flash).
    static let shared = HomeViewModel()

    enum State {
        case idle, loading, loaded
        case error(String)
    }

    /// The personalized radar family — global playlist IDs whose content is
    /// generated per logged-in account (same list YesPlayMusic special-cases).
    static let radarPlaylistIDs = [
        3_136_952_023, // 私人雷达
        2_829_883_282, // 华语私人雷达
        2_829_816_518, // 欧美私人雷达
        2_829_896_389, // 日系私人雷达
    ]

    struct RadarPlaylist: Identifiable, Hashable {
        let id: Int
        let title: String
        let subtitle: String?
        let coverURL: String?
    }

    var state: State = .idle
    var recommendPlaylists: [PlaylistSummary] = []
    var radarPlaylists: [RadarPlaylist] = []
    var toplists: [ToplistItem] = []
    var newAlbums: [AlbumSummary] = []
    var topArtists: [ArtistSummary] = []
    var dailyFirstCover: String?
    private var loadedContext: String?
    private var loadGeneration = 0

    func load(loggedIn: Bool, userID: Int?) async {
        let context = loggedIn ? "user:\(userID ?? 0)" : "guest"
        if case .loaded = state, loadedContext == context { return }
        loadGeneration += 1
        let generation = loadGeneration
        if loadedContext != context {
            clearContent()
        }
        state = .loading

        async let playlistsTask = fetchRecommendPlaylists(loggedIn: loggedIn)
        async let toplistsTask = try? NeteaseAPI.toplists()
        async let albumsTask = try? NeteaseAPI.newAlbums(limit: 20)
        async let artistsTask = try? NeteaseAPI.topArtists()

        let playlists = await playlistsTask
        guard generation == loadGeneration else { return }
        let loadedToplists = (await toplistsTask ?? []).filter {
            [19_723_756, 3_779_629, 2_884_035, 3_778_678, 60198].contains($0.id)
        }
        let loadedAlbums = await albumsTask ?? []
        let artists = await artistsTask ?? []
        guard generation == loadGeneration else { return }
        recommendPlaylists = playlists
        toplists = loadedToplists
        newAlbums = loadedAlbums
        topArtists = Array(artists.shuffled().prefix(6))

        if loggedIn {
            if let daily = try? await NeteaseAPI.dailyRecommendSongs() {
                guard generation == loadGeneration else { return }
                dailyFirstCover = daily.first?.album.picUrl
            }
            await loadRadarPlaylists(generation: generation)
            guard generation == loadGeneration else { return }
        }

        loadedContext = context
        state = playlists.isEmpty && newAlbums.isEmpty ? .error(String(localized: "网络连接失败")) : .loaded
    }

    func reload(loggedIn: Bool, userID: Int?) async {
        state = .idle
        await load(loggedIn: loggedIn, userID: userID)
    }

    private func loadRadarPlaylists(generation: Int) async {
        let briefs = await withTaskGroup(of: (Int, NeteaseAPI.PlaylistBrief.Body?).self) { group in
            for id in Self.radarPlaylistIDs {
                group.addTask {
                    (id, try? await NeteaseAPI.playlistBrief(id: id))
                }
            }
            var byID: [Int: NeteaseAPI.PlaylistBrief.Body] = [:]
            for await (id, brief) in group {
                if let brief { byID[id] = brief }
            }
            return byID
        }
        guard generation == loadGeneration else { return }
        radarPlaylists = Self.radarPlaylistIDs.compactMap { id in
            guard let brief = briefs[id] else { return nil }
            // Names arrive as "今天从《…》听起|私人雷达" — split into title/subtitle.
            let parts = (brief.name ?? "").components(separatedBy: "|")
            let title = parts.count > 1 ? parts.last! : (brief.name ?? String(localized: "雷达歌单"))
            let subtitle = parts.count > 1 ? parts.dropLast().joined(separator: "|") : nil
            return RadarPlaylist(id: id, title: title, subtitle: subtitle, coverURL: brief.coverImgUrl)
        }
    }

    private func clearContent() {
        recommendPlaylists = []
        radarPlaylists = []
        toplists = []
        newAlbums = []
        topArtists = []
        dailyFirstCover = nil
    }

    private func fetchRecommendPlaylists(loggedIn: Bool) async -> [PlaylistSummary] {
        if loggedIn {
            async let recommend = try? NeteaseAPI.recommendResource()
            async let personalized = try? NeteaseAPI.personalizedPlaylists(limit: 30)
            let head = await recommend ?? []
            let tail = await personalized ?? []
            var seen = Set<Int>()
            return (head + tail).filter { seen.insert($0.id).inserted }
        }
        return (try? await NeteaseAPI.personalizedPlaylists(limit: 30)) ?? []
    }
}

struct HomeView: View {
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
                    HomeGreeting(nickname: account.profile?.nickname)
                        .padding(.horizontal, Theme.Layout.contentInset)
                        .padding(.top, 14)
                        .padding(.bottom, 26)
                    switch model.state {
                    case .idle, .loading:
                        loadingBody
                    case .error(let message):
                        ErrorStateView(message: message) {
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
            .hoverScrollIndicators()
            .onChange(of: scrollToTopRequest) {
                withAnimation(AppAnimation.smooth) {
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
        VStack(alignment: .leading, spacing: 40) {
            HStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView(cornerRadius: Theme.Radius.large)
                        .frame(height: 150)
                }
            }
            SkeletonShelf()
            SkeletonShelf()
        }
        .padding(.horizontal, Theme.Layout.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadedBody: some View {
        LazyVStack(alignment: .leading, spacing: 40) {
            featureCardRow

            if !model.recommendPlaylists.isEmpty {
                Shelf(title: "推荐歌单") {
                    ForEach(Array(model.recommendPlaylists.prefix(12).enumerated()), id: \.element.id) { index, playlist in
                        playlistCard(playlist)
                            .staggeredAppearance(index: index, id: "home-rec-\(playlist.id)")
                    }
                }
            }

            if !model.radarPlaylists.isEmpty {
                Shelf(title: "雷达歌单") {
                    ForEach(model.radarPlaylists) { radar in
                        NavigationCoverCard(
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
                Shelf(title: "排行榜", seeAll: nil) {
                    ForEach(model.toplists) { toplist in
                        ToplistCard(toplist: toplist)
                    }
                }
            }

            if !model.newAlbums.isEmpty {
                Shelf(title: "新碟上架") {
                    ForEach(model.newAlbums) { album in
                        albumCard(album)
                    }
                }
            }

            if !model.topArtists.isEmpty {
                Shelf(title: "推荐歌手") {
                    ForEach(model.topArtists) { artist in
                        NavigationLink(value: Destination.artist(artist.id)) {
                            ArtistPortrait(url: artist.picUrl?.resizedImageURL(256), name: artist.name)
                        }
                        .buttonStyle(.interactiveCard)
                    }
                }
            }

            ColophonView()
        }
        .padding(.bottom, Theme.Layout.contentInset - 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Feature cards

    private var featureCardRow: some View {
        HStack(spacing: 18) {
            if account.isLoggedIn {
                NavigationLink(value: Destination.daily) {
                    FeatureCard(kind: .daily(coverURL: model.dailyFirstCover?.resizedImageURL(256)),
                                title: "每日推荐", subtitle: "依你的口味，每日一笺")
                }
                .buttonStyle(.plain)

                Button {
                    player.startFM()
                } label: {
                    FeatureCard(kind: .fm, title: "私人漫游", subtitle: "随心而行，一曲一山")
                }
                .buttonStyle(.plain)

                Button {
                    startHeartbeatMode()
                } label: {
                    FeatureCard(kind: .heartbeat, title: "心动模式", subtitle: "红心所系，相似而来")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    openLogin()
                } label: {
                    FeatureCard(kind: .login, title: "登录网易云音乐",
                                subtitle: "解锁每日推荐、私人漫游与心动模式")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Layout.contentInset)
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
        NavigationCoverCard(
            destination: .playlist(playlist.id),
            coverURL: playlist.coverURL?.resizedImageURL(384),
            title: playlist.name,
            subtitle: playlist.copywriter,
            playCount: playlist.playCount,
            onPlay: { playPlaylist(playlist.id) }
        )
    }

    private func albumCard(_ album: AlbumSummary) -> some View {
        NavigationCoverCard(
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
            guard !tracks.isEmpty else { return }
            player.play(tracks: tracks, source: .playlist(id))
        }
    }
}

// MARK: - Greeting

/// Time-of-day greeting, the date written in Chinese numerals, the current
/// solar term stamped as a seal, and a line of seasonal verse.
private struct HomeGreeting: View {
    let nickname: String?

    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let now = Date.now
        let term = SolarTerm.current(now)
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(ChineseDate.string(for: now))
                    .font(.system(size: 11.5, weight: .medium))
                    .tracking(2.5)
                    .foregroundStyle(Theme.ink.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(Self.greeting(for: now))
                    if let nickname, !nickname.isEmpty {
                        Text("，")
                        Text(nickname)
                    }
                }
                .font(.serif(32, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 14, height: 1.2)
                    Text(term.verse)
                        .font(.serif(13.5))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink.opacity(0.62))
                }
            }
            Spacer(minLength: 24)
            SealStamp(text: term.name, size: 30, vertical: true)
                .rotationEffect(.degrees(stamped ? -4 : -16))
                .scaleEffect(stamped ? 1 : 1.5)
                .opacity(stamped ? 0.92 : 0)
                .padding(.top, 4)
                .padding(.trailing, 6)
                .help("节气 · \(term.name)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottomTrailing) {
            InkMountains()
                .frame(width: 560, height: 120)
                .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
                .offset(x: 28, y: 22)
        }
        .onAppear {
            guard !stamped else { return }
            if reduceMotion {
                stamped = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.62).delay(0.45)) { stamped = true }
            }
        }
    }

    static func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<9: return String(localized: "早安")
        case 9..<12: return String(localized: "上午好")
        case 12..<14: return String(localized: "午安")
        case 14..<18: return String(localized: "下午好")
        case 18..<23: return String(localized: "晚上好")
        default: return String(localized: "夜深了")
        }
    }
}

enum ChineseDate {
    private static let digits = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    private static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    static func numeral(_ value: Int) -> String {
        switch value {
        case 0..<10: return digits[value]
        case 10: return "十"
        case 11..<20: return "十" + digits[value % 10]
        default:
            return digits[value / 10] + "十" + (value % 10 == 0 ? "" : digits[value % 10])
        }
    }

    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        return "\(numeral(month))月\(numeral(day))日 · 星期\(weekdays[(weekday - 1) % 7])"
    }
}

// MARK: - Feature card

struct FeatureCard: View {
    enum Kind {
        case daily(coverURL: URL?)
        case fm, heartbeat, login
    }

    let kind: Kind
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.serif(19, .bold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovering ? Theme.accent : Theme.ink.opacity(0.35))
                    .offset(x: isHovering && !reduceMotion ? 3 : 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(alignment: .topTrailing) { illustration }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .paperSheet(cornerRadius: Theme.Radius.large, lifted: isHovering)
        .offset(y: isHovering && !reduceMotion ? -3 : 0)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : AppAnimation.spring, value: isHovering)
    }

    @ViewBuilder
    private var illustration: some View {
        switch kind {
        case .daily(let coverURL):
            HStack(alignment: .top, spacing: 12) {
                if let coverURL {
                    CachedAsyncImage(url: coverURL)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 0.75))
                        .shadow(color: Theme.shadow, radius: isHovering ? 8 : 3, y: 3)
                        .rotationEffect(.degrees(isHovering && !reduceMotion ? 0 : 6))
                        .padding(.top, 8)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: .now))")
                        .font(.serif(58, .bold))
                        .foregroundStyle(Theme.ink.opacity(0.88))
                    Text(ChineseDate.numeral(Calendar.current.component(.month, from: .now)) + "月")
                        .font(.serif(11, .medium))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, 10)
            .padding(.trailing, 20)
        case .fm:
            InkMountains(seed: 3.1)
                .frame(width: 260, height: 104)
                .offset(x: isHovering && !reduceMotion ? -18 : 0, y: 0)
                .animation(.easeInOut(duration: 2.4), value: isHovering)
                .mask(LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .center))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Theme.accent.opacity(0.85))
                        .frame(width: 16, height: 16)
                        .offset(x: isHovering && !reduceMotion ? -30 : -46, y: isHovering && !reduceMotion ? 10 : 20)
                        .animation(.easeInOut(duration: 2.4), value: isHovering)
                }
                .padding(.top, 8)
        case .heartbeat:
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Enso(progress: 1, lineWidth: 2.2, color: Theme.ink.opacity(0.18 - Double(ring) * 0.04),
                         startAngle: -100 + Double(ring) * 70)
                        .frame(width: 64 + CGFloat(ring) * 34, height: 64 + CGFloat(ring) * 34)
                        .scaleEffect(isHovering && !reduceMotion ? 1.08 : 1)
                        .animation(.easeOut(duration: 0.8).delay(Double(ring) * 0.08), value: isHovering)
                }
                SealStamp(text: "心", size: 34)
                    .rotationEffect(.degrees(isHovering ? 0 : -6))
                    .scaleEffect(isHovering && !reduceMotion ? 1.06 : 1)
            }
            .frame(width: 150, height: 150)
            .offset(x: 28, y: -18)
        case .login:
            Enso(progress: isHovering ? 1 : 0.82, lineWidth: 5, color: Theme.ink.opacity(0.75))
                .frame(width: 92, height: 92)
                .padding(18)
                .animation(.easeOut(duration: 0.6), value: isHovering)
        }
    }
}

// MARK: - Toplist card

/// A chart cover with its update cadence written vertically, like a book spine.
struct ToplistCard: View {
    let toplist: ToplistItem
    @State private var isHovering = false

    var body: some View {
        NavigationLink(value: Destination.playlist(toplist.id)) {
            VStack(alignment: .leading, spacing: 9) {
                CoverArtwork(url: toplist.coverImgUrl?.resizedImageURL(384), lifted: isHovering)
                    .overlay(alignment: .bottomLeading) {
                        if let frequency = toplist.updateFrequency, !frequency.isEmpty {
                            Text(frequency)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(red: 0.98, green: 0.96, blue: 0.92))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.1, green: 0.09, blue: 0.08).opacity(0.45), in: Capsule())
                                .padding(8)
                        }
                    }
                Text(toplist.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.ink.opacity(0.92))
                    .lineLimit(1)
            }
            .frame(width: Theme.Layout.cardSize, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.interactiveCard)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Colophon

/// The end of the page: a small ensō and a line of quiet.
struct ColophonView: View {
    var body: some View {
        VStack(spacing: 10) {
            Enso(lineWidth: 2.4, color: Theme.ink.opacity(0.28))
                .frame(width: 30, height: 30)
            Text("一曲终了，余音未尽")
                .font(.serif(11.5))
                .tracking(3)
                .foregroundStyle(Theme.ink.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
}
