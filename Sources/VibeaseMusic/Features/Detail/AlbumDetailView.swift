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
            VStack(alignment: .leading, spacing: 26) {
                if let album {
                    header(album)
                        .padding(.horizontal, Theme.Layout.contentInset)
                        .padding(.top, 22)

                    ForEach(discs, id: \.self) { disc in
                        if discs.count > 1 {
                            Text("Disc \(disc)")
                                .font(.serif(14, .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.ink.opacity(0.6))
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
                    InkLoader(size: 40, color: Theme.ink.opacity(0.55))
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
        .background(alignment: .top) {
            ArtworkWash(url: album?.picUrl?.resizedImageURL(128))
                .ignoresSafeArea()
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
        HStack(alignment: .bottom, spacing: 28) {
            // An album sleeve with its record peeking out on hover.
            AlbumSleeve(url: album.picUrl?.resizedImageURL(512))

            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: (album.subType?.isEmpty == false ? album.subType! : String(localized: "专辑")) + " · ALBUM")
                Text(album.name)
                    .font(.serif(29, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .lineLimit(2)

                if let artist = album.artist {
                    NavigationLink(value: Destination.artist(artist.id)) {
                        HStack(spacing: 4) {
                            Text(artist.name)
                                .font(.system(size: 13.5, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Text("\(tracks.count) 首 · \(totalDuration) · \(Formatters.date(fromMS: album.publishTime))")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.42))

                if let description = album.description, !description.isEmpty {
                    Button {
                        showFullDescription = true
                    } label: {
                        Text(description.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink.opacity(0.55))
                            .lineSpacing(2)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showFullDescription, arrowEdge: .bottom) {
                        ScrollView {
                            Text(description)
                                .font(.system(size: 13))
                                .lineSpacing(4)
                                .foregroundStyle(Theme.ink)
                                .padding(18)
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
                    }
                    .buttonStyle(.ink)

                    if account.isLoggedIn {
                        Button {
                            toggleSubscribe()
                        } label: {
                            Label(isSubscribed ? String(localized: "已收藏") : String(localized: "收藏"),
                                  systemImage: isSubscribed ? "checkmark" : "plus")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.inkOutline)
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
        .font(.serif(11.5))
        .tracking(1)
        .foregroundStyle(Theme.ink.opacity(0.4))
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.accent.opacity(0.6)).frame(width: 1.5)
        }
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

/// Album cover as a sleeve with its record peeking out; hovering draws it further out.
private struct AlbumSleeve: View {
    let url: URL?
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            ZStack {
                Circle().fill(Color(red: 0.1, green: 0.09, blue: 0.08))
                ForEach(0..<5, id: \.self) { ring in
                    Circle()
                        .strokeBorder(.white.opacity(0.05), lineWidth: 0.6)
                        .padding(CGFloat(14 + ring * 12))
                }
                Circle().fill(Theme.accent).frame(width: 52, height: 52)
                Circle().fill(Theme.paper).frame(width: 6, height: 6)
            }
            .frame(width: 186, height: 186)
            .rotationEffect(.degrees(isHovering ? 60 : 0))
            .offset(x: isHovering ? 66 : 40)
            CoverArtwork(url: url, size: 200, lifted: true)
        }
        .frame(width: 256, height: 200, alignment: .leading)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isHovering)
    }
}
