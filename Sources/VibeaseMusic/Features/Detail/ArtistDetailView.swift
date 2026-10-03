import SwiftUI

struct ArtistDetailView: View {
    let artistID: Int

    @State private var artist: ArtistSummary?
    @State private var hotSongs: [Track] = []
    @State private var albums: [AlbumSummary] = []
    @State private var epsAndSingles: [AlbumSummary] = []
    @State private var similar: [ArtistSummary] = []
    @State private var isFollowed = false
    @State private var showAllSongs = false
    @State private var showArtistInfo = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if let artist {
                    hero(artist)

                    featuredContent
                        .padding(.horizontal, Theme.Layout.contentInset)

                    if showAllSongs {
                        TrackListView(tracks: Array(hotSongs.prefix(50)), style: .compact, source: .artist(artistID))
                            .padding(.horizontal, Theme.Layout.contentInset - 10)
                    }

                    if !albums.isEmpty {
                        Shelf(title: "专辑", destination: .artistAlbums(artistID, artist.name)) {
                            ForEach(albums) { album in albumCard(album) }
                        }
                    }

                    if !epsAndSingles.isEmpty {
                        Shelf(title: "EP 与单曲", destination: .artistAlbums(artistID, artist.name)) {
                            ForEach(epsAndSingles) { album in albumCard(album) }
                        }
                    }

                    if !similar.isEmpty {
                        Shelf(title: "相似歌手") {
                            ForEach(similar.prefix(10)) { other in
                                NavigationLink(value: Destination.artist(other.id)) {
                                    ArtistPortrait(url: other.picUrl?.resizedImageURL(256), name: other.name)
                                }
                                .buttonStyle(.interactiveCard)
                            }
                        }
                    }
                } else if isLoading {
                    InkLoader(size: 40, color: Theme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) { Task { await load() } }
                        .frame(minHeight: 400)
                }
                Color.clear.frame(height: 8)
            }
        }
        .background(alignment: .top) {
            ArtworkWash(url: artist?.picUrl?.resizedImageURL(128), height: 480)
                .ignoresSafeArea()
        }
        .hoverScrollIndicators()
        .navigationTitle(artist?.name ?? String(localized: "歌手"))
        .task(id: artistID) { await load() }
    }

    private var latestRelease: AlbumSummary? {
        (albums + epsAndSingles).max { $0.publishTime < $1.publishTime }
    }

    private var featuredContent: some View {
        HStack(alignment: .top, spacing: 30) {
            if let release = latestRelease {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "最新发行")
                    NavigationLink(value: Destination.album(release.id)) {
                        HStack(alignment: .top, spacing: 12) {
                            CoverArtwork(url: release.picUrl?.resizedImageURL(384), size: 136)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(release.publishYear)
                                    .font(.serif(12, .medium))
                                    .tracking(1.5)
                                    .foregroundStyle(Theme.accent)
                                Text(release.name)
                                    .font(.serif(15, .bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(3)
                                Text("\(release.size) 首歌曲")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.interactiveCard)
                }
                .frame(width: 270, alignment: .leading)
            }

            if !hotSongs.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SectionHeader(title: "歌曲排行")
                        Spacer()
                        if hotSongs.count > 6 {
                            Button(showAllSongs ? "收起" : "查看全部") {
                                withAnimation(AppAnimation.standard) { showAllSongs.toggle() }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                        }
                    }
                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 4) {
                            ForEach(Array(hotSongs.prefix(3))) { track in topSongRow(track) }
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            ForEach(Array(hotSongs.dropFirst(3).prefix(3))) { track in topSongRow(track) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func topSongRow(_ track: Track) -> some View {
        HStack(spacing: 6) {
            Button {
                player.play(tracks: hotSongs, source: .artist(artistID), startAt: track)
            } label: {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", (hotSongs.firstIndex { $0.id == track.id } ?? 0) + 1))
                        .font(.serif(13, .bold).monospacedDigit())
                        .foregroundStyle(player.currentTrack?.id == track.id ? Theme.accent : Theme.ink.opacity(0.35))
                        .frame(width: 22, alignment: .leading)
                    CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(96), animated: false)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(player.currentTrack?.id == track.id ? Theme.accent : Theme.ink.opacity(0.92))
                            .lineLimit(1)
                        Text(track.album.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button("播放") { player.play(tracks: hotSongs, source: .artist(artistID), startAt: track) }
                NavigationLink("查看专辑", value: Destination.album(track.album.id))
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.5))
                    .frame(width: 24, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("更多选项")
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 0.75) }
    }

    private func hero(_ artist: ArtistSummary) -> some View {
        HStack(alignment: .center, spacing: 40) {
            ZStack {
                Enso(lineWidth: 6, color: Theme.ink.opacity(0.8), startAngle: -60)
                    .frame(width: 218, height: 218)
                CachedAsyncImage(url: artist.picUrl?.resizedImageURL(512))
                    .frame(width: 176, height: 176)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .shadow(color: Theme.shadow.opacity(1.2), radius: 18, y: 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: String(localized: "歌手 · ARTIST"))
                Text(artist.name)
                    .font(.serif(40, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !artist.alias.isEmpty {
                    Text(artist.alias.joined(separator: " / "))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .lineLimit(1)
                }
                Text("\(artist.musicSize) 首歌曲 · \(artist.albumSize) 张专辑")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.42))

                HStack(spacing: 10) {
                    Button { player.play(tracks: hotSongs, source: .artist(artistID)) } label: {
                        Label("播放热门", systemImage: "play.fill")
                    }
                    .buttonStyle(.ink)
                    .disabled(hotSongs.isEmpty)

                    if account.isLoggedIn {
                        Button { toggleFollow() } label: {
                            Label(isFollowed ? String(localized: "已关注") : String(localized: "关注"),
                                  systemImage: isFollowed ? "checkmark" : "plus")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.inkOutline)
                    }

                    Button { showArtistInfo.toggle() } label: {
                        Label("简介", systemImage: "text.alignleft")
                    }
                    .buttonStyle(.inkOutline)
                    .popover(isPresented: $showArtistInfo) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(artist.name)
                                    .font(.serif(17, .bold))
                                    .foregroundStyle(Theme.ink)
                                Text("\(artist.musicSize) 首歌曲 · \(artist.albumSize) 张专辑")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                                if let description = artist.briefDesc, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 13))
                                        .lineSpacing(4)
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            .padding(20)
                            .frame(width: 340, alignment: .leading)
                        }
                        .frame(maxHeight: 420)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Layout.contentInset + 8)
        .padding(.top, 36)
        .padding(.bottom, 6)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await NeteaseAPI.artist(id: artistID)
            artist = response.artist
            hotSongs = response.hotSongs
            isFollowed = response.artist.followed
            isLoading = false

            if let result = try? await NeteaseAPI.artistAlbums(id: artistID, limit: 60) {
                albums = result.hotAlbums.filter { $0.size > 1 }
                epsAndSingles = result.hotAlbums.filter { $0.size <= 1 }
            }
            if account.isLoggedIn {
                similar = (try? await NeteaseAPI.similarArtists(id: artistID)) ?? []
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func albumCard(_ album: AlbumSummary) -> some View {
        NavigationLink(value: Destination.album(album.id)) {
            CoverCardBody(coverURL: album.picUrl?.resizedImageURL(384), title: album.name, subtitle: album.publishYear)
        }
        .buttonStyle(.interactiveCard)
    }

    private func toggleFollow() {
        Task {
            do {
                try await NeteaseAPI.subscribeArtist(id: artistID, subscribe: !isFollowed)
                isFollowed.toggle()
                ToastCenter.shared.show(isFollowed ? String(localized: "已关注歌手") : String(localized: "已取消关注"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }
}
