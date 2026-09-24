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
                                    VStack(spacing: 10) {
                                        CachedAsyncImage(url: other.picUrl?.resizedImageURL(256))
                                            .frame(width: 128, height: 128)
                                            .clipShape(Circle())
                                        Text(other.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 140)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.interactiveCard)
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) { Task { await load() } }
                        .frame(minHeight: 400)
                }
                Color.clear.frame(height: 8)
            }
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
                    Text("最新发行")
                        .font(.system(size: 18, weight: .bold))
                    NavigationLink(value: Destination.album(release.id)) {
                        HStack(alignment: .top, spacing: 12) {
                            CachedAsyncImage(url: release.picUrl?.resizedImageURL(384))
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(release.publishYear)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(release.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(3)
                                Text("\(release.size) 首歌曲")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
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
                        Text("歌曲排行")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                        if hotSongs.count > 6 {
                            Button(showAllSongs ? "收起" : "查看全部") {
                                withAnimation(AppAnimation.standard) { showAllSongs.toggle() }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
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
                    CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(96), animated: false)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .lineLimit(1)
                        Text(track.album.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
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
                    .frame(width: 24, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("更多选项")
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) { Rectangle().fill(.primary.opacity(0.08)).frame(height: 0.5) }
    }

    private func hero(_ artist: ArtistSummary) -> some View {
        ZStack {
            CachedAsyncImage(url: artist.picUrl?.resizedImageURL(512), animated: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 70)
                .overlay(.black.opacity(0.56))
            LinearGradient(colors: [.clear, Color(nsColor: .windowBackgroundColor).opacity(0.6)],
                           startPoint: .center, endPoint: .bottom)

            VStack(spacing: 10) {
                CachedAsyncImage(url: artist.picUrl?.resizedImageURL(512))
                    .frame(width: 164, height: 164)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                Text(artist.name)
                    .font(.system(size: 34, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !artist.alias.isEmpty {
                    Text(artist.alias.joined(separator: " / "))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                HStack(spacing: 16) {
                    Button { showArtistInfo.toggle() } label: {
                        Image(systemName: "info")
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .popover(isPresented: $showArtistInfo) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(artist.name).font(.headline)
                            Text("\(artist.musicSize) 首歌曲 · \(artist.albumSize) 张专辑")
                                .foregroundStyle(.secondary)
                            if let description = artist.briefDesc, !description.isEmpty {
                                Text(description).font(.subheadline)
                            }
                        }
                        .padding(18)
                        .frame(width: 300, alignment: .leading)
                    }

                    Button { player.play(tracks: hotSongs, source: .artist(artistID)) } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .frame(width: 58, height: 58)
                            .foregroundStyle(.black)
                            .background(.white, in: Circle())
                    }
                    .disabled(hotSongs.isEmpty)
                    .accessibilityLabel("播放热门")

                    if account.isLoggedIn {
                        Button { toggleFollow() } label: {
                            Image(systemName: isFollowed ? "checkmark" : "plus")
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15), in: Circle())
                        }
                        .accessibilityLabel(isFollowed ? "已关注" : "关注")
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .frame(height: 365)
        .clipped()
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
