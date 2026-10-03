import SwiftUI

@MainActor
@Observable
final class PlaylistDetailViewModel {
    let playlistID: Int
    var detail: PlaylistDetail?
    var tracks: [Track] = []
    var privileges: [Int: TrackPrivilege] = [:]
    var isLoading = true
    var isLoadingMore = false
    var errorMessage: String?
    var filter = ""
    /// Bumped on each load so an older in-flight load can't append duplicates.
    private var loadGeneration = 0

    init(playlistID: Int) {
        self.playlistID = playlistID
    }

    var filteredTracks: [Track] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return tracks }
        return tracks.filter {
            $0.name.lowercased().contains(query)
                || $0.artistNames.lowercased().contains(query)
                || $0.album.name.lowercased().contains(query)
        }
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = tracks.isEmpty
        errorMessage = nil
        do {
            let response = try await NeteaseAPI.playlistDetail(id: playlistID)
            guard generation == loadGeneration else { return }
            detail = response.playlist
            tracks = response.playlist.tracks
            merge(privileges: response.privileges)
            isLoading = false
            await loadRemainingTracks(generation: generation)
        } catch {
            guard generation == loadGeneration else { return }
            isLoading = false
            if tracks.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    private func loadRemainingTracks(generation: Int) async {
        guard let detail, tracks.count < detail.trackIds.count else { return }
        isLoadingMore = true
        defer { if generation == loadGeneration { isLoadingMore = false } }
        let remaining = detail.trackIds.map(\.id).dropFirst(tracks.count)
        for chunk in stride(from: 0, to: remaining.count, by: 500)
            .map({ Array(remaining.dropFirst($0).prefix(500)) }) {
            guard let response = try? await NeteaseAPI.songDetails(ids: chunk),
                  generation == loadGeneration else { break }
            tracks += response.songs
            merge(privileges: response.privileges)
        }
    }

    private func merge(privileges list: [TrackPrivilege]?) {
        for privilege in list ?? [] {
            privileges[privilege.id] = privilege
        }
    }

    func remove(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
    }
}

struct PlaylistDetailView: View {
    let playlistID: Int
    var isLikedList = false

    @State private var model: PlaylistDetailViewModel
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @State private var showFullDescription = false

    init(playlistID: Int, isLikedList: Bool = false) {
        self.playlistID = playlistID
        self.isLikedList = isLikedList
        _model = State(initialValue: PlaylistDetailViewModel(playlistID: playlistID))
    }

    private var isOwnPlaylist: Bool {
        model.detail?.creator?.userId == account.profile?.userId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if let detail = model.detail {
                    header(detail)
                        .padding(.horizontal, Theme.Layout.contentInset)
                        .padding(.top, 22)

                    TrackListView(
                        tracks: model.filteredTracks,
                        privileges: model.privileges,
                        source: .playlist(playlistID),
                        removableFromPlaylistID: isOwnPlaylist ? playlistID : nil,
                        onRemoved: { model.remove($0) }
                    )
                    .padding(.horizontal, Theme.Layout.contentInset - 10)

                    if model.isLoadingMore {
                        HStack {
                            Spacer()
                            InkLoader(size: 24, color: Theme.ink.opacity(0.5))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                } else if model.isLoading {
                    loadingHeader
                } else if let message = model.errorMessage {
                    ErrorStateView(message: message) {
                        Task { await model.load() }
                    }
                    .frame(minHeight: 400)
                }
                Color.clear.frame(height: 8)
            }
        }
        .background(alignment: .top) {
            ArtworkWash(url: model.detail?.coverImgUrl?.resizedImageURL(128))
                .ignoresSafeArea()
        }
        .hoverScrollIndicators()
        .navigationTitle(model.detail?.name ?? String(localized: "歌单"))
        .task(id: playlistID) {
            await model.load()
        }
    }

    // MARK: - Header

    private func header(_ detail: PlaylistDetail) -> some View {
        HStack(alignment: .bottom, spacing: 28) {
            CoverArtwork(url: detail.coverImgUrl?.resizedImageURL(512), size: 200, lifted: true)

            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: isLikedList ? String(localized: "我喜欢的音乐") : String(localized: "歌单 · PLAYLIST"))
                Text(detail.name)
                    .font(.serif(29, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .lineLimit(2)

                if let creator = detail.creator {
                    HStack(spacing: 6) {
                        CachedAsyncImage(url: creator.avatarUrl?.resizedImageURL(48), animated: false)
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.5))
                        Text(creator.nickname)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                    }
                }

                Text("\(detail.trackCount) 首 · \(Formatters.playCount(detail.playCount)) 次播放 · 更新于 \(Formatters.date(fromMS: detail.updateTime))")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.42))

                if let description = detail.description, !description.isEmpty {
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

                actionRow(detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 210)
    }

    private func actionRow(_ detail: PlaylistDetail) -> some View {
        HStack(spacing: 10) {
            Button {
                player.play(tracks: playable, source: .playlist(playlistID))
            } label: {
                Label("播放全部", systemImage: "play.fill")
            }
            .buttonStyle(.ink)

            if isLikedList {
                Button {
                    startHeartbeat()
                } label: {
                    Label("心动模式", systemImage: "heart")
                }
                .buttonStyle(.inkOutline)
            } else if !isOwnPlaylist, account.isLoggedIn {
                Button {
                    toggleSubscribe(detail)
                } label: {
                    Label(detail.subscribed ? String(localized: "已收藏") : String(localized: "收藏"),
                          systemImage: detail.subscribed ? "checkmark" : "plus")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.inkOutline)
            }

            Spacer()

            InkFilterField(placeholder: "搜索歌单内歌曲", text: Bindable(model).filter)
        }
    }

    private var playable: [Track] {
        // With unblock enabled, gray tracks resolve from third-party sources —
        // keep them in the play-all queue (mirrors TrackListView).
        if SettingsManager.shared.enableUnblock { return model.tracks }
        return model.tracks.filter {
            $0.playability(privilege: model.privileges[$0.id],
                           isLoggedIn: account.isLoggedIn,
                           vipType: account.vipType) == .playable
        }
    }

    private func startHeartbeat() {
        Task {
            guard let seed = playable.randomElement() else { return }
            do {
                let tracks = try await NeteaseAPI.intelligenceList(songID: seed.id, playlistID: playlistID)
                guard !tracks.isEmpty else {
                    ToastCenter.shared.show(String(localized: "心动模式暂时不可用"))
                    return
                }
                player.play(tracks: tracks, source: .playlist(playlistID))
                ToastCenter.shared.show(String(localized: "已开启心动模式"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    private func toggleSubscribe(_ detail: PlaylistDetail) {
        Task {
            do {
                try await NeteaseAPI.subscribePlaylist(id: playlistID, subscribe: !detail.subscribed)
                await model.load()
                await account.refreshLibrary()
                ToastCenter.shared.show(detail.subscribed ? String(localized: "已取消收藏") : String(localized: "已收藏歌单"))
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        }
    }

    private var loadingHeader: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom, spacing: 24) {
                SkeletonView(cornerRadius: Theme.Radius.large)
                    .frame(width: 200, height: 200)
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonView(cornerRadius: 4).frame(width: 60, height: 12)
                    SkeletonView(cornerRadius: 4).frame(width: 280, height: 28)
                    SkeletonView(cornerRadius: 4).frame(width: 180, height: 12)
                    Spacer()
                    SkeletonView(cornerRadius: 16).frame(width: 110, height: 34)
                }
                .frame(height: 200)
            }
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonView(cornerRadius: 6).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(cornerRadius: 4).frame(width: 200, height: 12)
                        SkeletonView(cornerRadius: 4).frame(width: 120, height: 10)
                    }
                    Spacer()
                }
            }
        }
        .padding(Theme.Layout.contentInset)
    }
}
