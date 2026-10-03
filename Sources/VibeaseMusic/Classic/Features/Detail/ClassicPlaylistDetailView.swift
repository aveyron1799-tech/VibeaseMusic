// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI


struct ClassicPlaylistDetailView: View {
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
            VStack(alignment: .leading, spacing: 20) {
                if let detail = model.detail {
                    header(detail)
                        .padding(.horizontal, ClassicTheme.Layout.contentInset)
                        .padding(.top, 16)

                    ClassicTrackListView(
                        tracks: model.filteredTracks,
                        privileges: model.privileges,
                        source: .playlist(playlistID),
                        removableFromPlaylistID: isOwnPlaylist ? playlistID : nil,
                        onRemoved: { model.remove($0) }
                    )
                    .padding(.horizontal, ClassicTheme.Layout.contentInset - 10)

                    if model.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView().controlSize(.small)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                } else if model.isLoading {
                    loadingHeader
                } else if let message = model.errorMessage {
                    ClassicErrorStateView(message: message) {
                        Task { await model.load() }
                    }
                    .frame(minHeight: 400)
                }
                Color.clear.frame(height: 8)
            }
        }
        .classicHoverScrollIndicators()
        .navigationTitle(model.detail?.name ?? String(localized: "歌单"))
        .task(id: playlistID) {
            await model.load()
        }
    }

    // MARK: - Header

    private func header(_ detail: PlaylistDetail) -> some View {
        HStack(alignment: .bottom, spacing: 24) {
            CachedAsyncImage(url: detail.coverImgUrl?.resizedImageURL(512))
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: ClassicTheme.Radius.large, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(isLikedList ? String(localized: "我喜欢的音乐") : String(localized: "歌单"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(detail.name)
                    .font(.title.weight(.bold))
                    .lineLimit(2)

                if let creator = detail.creator {
                    HStack(spacing: 6) {
                        CachedAsyncImage(url: creator.avatarUrl?.resizedImageURL(48), animated: false)
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                        Text(creator.nickname)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(detail.trackCount) 首 · \(Formatters.playCount(detail.playCount)) 次播放 · 更新于 \(Formatters.date(fromMS: detail.updateTime))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                if let description = detail.description, !description.isEmpty {
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(ClassicTheme.accentGradient, in: Capsule())
                    .shadow(color: ClassicTheme.accent.opacity(0.3), radius: 6, y: 2)
            }
            .buttonStyle(.classicPressable)

            if isLikedList {
                Button {
                    startHeartbeat()
                } label: {
                    Label("心动模式", systemImage: "heart.circle")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.classicPressable)
            } else if !isOwnPlaylist, account.isLoggedIn {
                Button {
                    toggleSubscribe(detail)
                } label: {
                    Label(detail.subscribed ? String(localized: "已收藏") : String(localized: "收藏"),
                          systemImage: detail.subscribed ? "checkmark" : "plus")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.classicPressable)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索歌单内歌曲", text: Bindable(model).filter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 130)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.primary.opacity(0.05), in: Capsule())
        }
    }

    private var playable: [Track] {
        // With unblock enabled, gray tracks resolve from third-party sources —
        // keep them in the play-all queue (mirrors ClassicTrackListView).
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
                ClassicSkeletonView(cornerRadius: ClassicTheme.Radius.large)
                    .frame(width: 200, height: 200)
                VStack(alignment: .leading, spacing: 10) {
                    ClassicSkeletonView(cornerRadius: 4).frame(width: 60, height: 12)
                    ClassicSkeletonView(cornerRadius: 4).frame(width: 280, height: 28)
                    ClassicSkeletonView(cornerRadius: 4).frame(width: 180, height: 12)
                    Spacer()
                    ClassicSkeletonView(cornerRadius: 16).frame(width: 110, height: 34)
                }
                .frame(height: 200)
            }
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 12) {
                    ClassicSkeletonView(cornerRadius: 6).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 6) {
                        ClassicSkeletonView(cornerRadius: 4).frame(width: 200, height: 12)
                        ClassicSkeletonView(cornerRadius: 4).frame(width: 120, height: 10)
                    }
                    Spacer()
                }
            }
        }
        .padding(ClassicTheme.Layout.contentInset)
    }
}
