import SwiftUI

struct AlbumDetailView: View {
    let albumID: Int

    @State private var album: AlbumDetail?
    @State private var tracks: [Track] = []
    @State private var otherAlbums: [AlbumSummary] = []
    @State private var isSubscribed = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showFullDescription = false

    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let album {
                    header(album)
                        .padding(.horizontal, Theme.Layout.contentInset)
                        .padding(.top, 16)

                    ForEach(discs, id: \.self) { disc in
                        if discs.count > 1 {
                            Text("Disc \(disc)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, Theme.Layout.contentInset)
                                .padding(.top, 4)
                        }
                        TrackListView(
                            tracks: tracks.filter { ($0.disc ?? "01") == disc },
                            style: .albumTrack,
                            source: .album(albumID)
                        )
                        .padding(.horizontal, Theme.Layout.contentInset - 10)
                    }

                    footer(album)
                        .padding(.horizontal, Theme.Layout.contentInset)

                    if !otherAlbums.isEmpty {
                        Shelf(title: "\(album.artist?.name ?? String(localized: "该歌手"))的其他专辑") {
                            ForEach(otherAlbums) { other in
                                NavigationLink(value: Destination.album(other.id)) {
                                    CoverCardBody(
                                        coverURL: other.picUrl?.resizedImageURL(384),
                                        title: other.name,
                                        subtitle: other.publishYear
                                    )
                                }
                                .buttonStyle(.interactiveCard)
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                    .frame(minHeight: 400)
                }
                Color.clear.frame(height: 8)
            }
        }
        .hoverScrollIndicators()
        .navigationTitle(album?.name ?? String(localized: "专辑"))
        .task(id: albumID) {
            await load()
        }
    }

    private var discs: [String] {
        var seen = Set<String>()
        return tracks.map { $0.disc ?? "01" }.filter { seen.insert($0).inserted }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await NeteaseAPI.album(id: albumID)
            album = response.album
            tracks = response.songs
            isLoading = false
            if let dynamic = try? await NeteaseAPI.albumDynamic(id: albumID) {
                isSubscribed = dynamic.isSub ?? false
            }
            if let artistID = response.album.artist?.id,
               let albums = try? await NeteaseAPI.artistAlbums(id: artistID, limit: 12) {
                otherAlbums = albums.hotAlbums.filter { $0.id != albumID }
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func header(_ album: AlbumDetail) -> some View {
        HStack(alignment: .bottom, spacing: 24) {
            CachedAsyncImage(url: album.picUrl?.resizedImageURL(512))
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(album.subType?.isEmpty == false ? album.subType! : String(localized: "专辑"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(album.name)
                    .font(.title.weight(.bold))
                    .lineLimit(2)

                if let artist = album.artist {
                    NavigationLink(value: Destination.artist(artist.id)) {
                        Text(artist.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Text("\(tracks.count) 首 · \(totalDuration) · \(Formatters.date(fromMS: album.publishTime))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                if let description = album.description, !description.isEmpty {
                    Button {
                        showFullDescription = true
                    } label: {
                        Text(description.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showFullDescription, arrowEdge: .bottom) {
                        ScrollView {
                            Text(description)
                                .font(.system(size: 13))
                                .padding(16)
                                .frame(width: 380, alignment: .leading)
                        }
                        .frame(maxHeight: 400)
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 10) {
                    Button {
                        player.play(tracks: tracks, source: .album(albumID))
                    } label: {
                        Label("播放", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Theme.accentGradient, in: Capsule())
                            .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 2)
                    }
                    .buttonStyle(.pressable)

                    if account.isLoggedIn {
                        Button {
                            toggleSubscribe()
                        } label: {
                            Label(isSubscribed ? String(localized: "已收藏") : String(localized: "收藏"),
                                  systemImage: isSubscribed ? "checkmark" : "plus")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 210)
    }

    private func footer(_ album: AlbumDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("发行于 \(Formatters.date(fromMS: album.publishTime))")
            if let company = album.company, !company.isEmpty {
                Text(company)
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.tertiary)
    }

    private var totalDuration: String {
        Formatters.longDuration(tracks.reduce(0) { $0 + $1.duration })
    }

    private func toggleSubscribe() {
        Task {
            do {
                try await NeteaseAPI.subscribeAlbum(id: albumID, subscribe: !isSubscribed)
                isSubscribed.toggle()
                ToastCenter.shared.show(isSubscribed ? String(localized: "已收藏专辑") : String(localized: "已取消收藏"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }
}
