import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Binding var showLogin: Bool
    let onHomeDoubleClick: () -> Void

    @Environment(AccountStore.self) private var account
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var avatarImage: NSImage?

    var body: some View {
        List {
            Section {
                SidebarBrand()
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 10, trailing: 6))
                row(.home, title: "推荐", icon: "house")
                row(.explore, title: "精选", icon: "square.grid.2x2")
                row(.fm, title: "漫游", icon: "wind")
            }

            if account.hasAuthCookie {
                Section {
                    row(.likedSongs, title: "我喜欢的音乐", icon: "heart")
                    row(.daily, title: "每日推荐", icon: "calendar")
                    row(.recents, title: "最近播放", icon: "clock")
                    row(.collections, title: "我的收藏", icon: "star")
                    row(.cloud, title: "音乐云盘", icon: "icloud")
                } header: {
                    SidebarSectionTitle("我的")
                }

                if !account.createdPlaylists.isEmpty {
                    Section {
                        ForEach(account.createdPlaylists) { playlist in
                            playlistRow(playlist)
                        }
                    } header: {
                        HStack {
                            SidebarSectionTitle("创建的歌单")
                            Spacer()
                            Button {
                                showNewPlaylist = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                    .frame(width: 16, height: 16)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            // Align with the trailing edge of the playlist rows
                            // (rows carry 6pt list inset + 8pt inner padding).
                            .padding(.trailing, 14)
                        }
                    }
                }

                if !account.subscribedPlaylists.isEmpty {
                    Section {
                        ForEach(account.subscribedPlaylists) { playlist in
                            playlistRow(playlist)
                        }
                    } header: {
                        SidebarSectionTitle("收藏的歌单")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background { PaperBackground(tone: .sidebar).ignoresSafeArea() }
        .thinAutoScrollIndicators(.vertical)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            accountFooter
        }
        .task(id: account.profile?.avatarUrl) {
            if let url = account.profile?.avatarUrl?.resizedImageURL(96) {
                avatarImage = await ImageCache.shared.image(for: url)
            } else {
                avatarImage = nil
            }
        }
        .alert("新建歌单", isPresented: $showNewPlaylist) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                newPlaylistName = ""
                guard !name.isEmpty else { return }
                Task {
                    do {
                        try await NeteaseAPI.createPlaylist(name: name, isPrivate: false)
                        await account.refreshLibrary()
                        ToastCenter.shared.show(String(localized: "歌单已创建"))
                    } catch {
                        ToastCenter.shared.show(error.localizedDescription)
                    }
                }
            }
            Button("取消", role: .cancel) { newPlaylistName = "" }
        }
    }

    private func row(_ item: SidebarItem, title: LocalizedStringKey, icon: String) -> some View {
        SidebarRow(
            title: title, icon: icon, isSelected: selection == item,
            action: { selection = item },
            onDoubleClick: item == .home ? onHomeDoubleClick : nil
        )
    }

    private func playlistRow(_ playlist: PlaylistSummary) -> some View {
        SidebarPlaylistRow(
            playlist: playlist,
            isSelected: selection == .playlist(playlist.id),
            action: { selection = .playlist(playlist.id) }
        )
        .contextMenu {
            Button("播放") {
                Task {
                    if let detail = try? await NeteaseAPI.playlistDetail(id: playlist.id) {
                        await playPlaylist(detail)
                    }
                }
            }
            Divider()
            if playlist.creator?.userId == account.profile?.userId {
                Button("删除歌单", role: .destructive) {
                    Task {
                        try? await NeteaseAPI.deletePlaylist(id: playlist.id)
                        await account.refreshLibrary()
                    }
                }
            } else {
                Button("取消收藏") {
                    Task {
                        try? await NeteaseAPI.subscribePlaylist(id: playlist.id, subscribe: false)
                        await account.refreshLibrary()
                    }
                }
            }
        }
    }

    private func playPlaylist(_ detail: NeteaseAPI.PlaylistDetailResponse) async {
        var tracks = detail.playlist.tracks
        if tracks.count < detail.playlist.trackCount {
            let ids = detail.playlist.trackIds.map(\.id)
            if let full = try? await NeteaseAPI.songDetails(ids: Array(ids.prefix(1000))) {
                tracks = full.songs
            }
        }
        PlayerService.shared.play(tracks: tracks, source: .playlist(detail.playlist.id))
    }

    @ViewBuilder
    private var accountFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 0.75)
                .padding(.horizontal, 14)
            if let profile = account.profile {
                AccountChip(profile: profile, avatarImage: avatarImage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            } else {
                Button {
                    showLogin = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Theme.ink.opacity(0.6))
                        Text("登录网易云音乐")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Theme.paperDeep.opacity(0.92))
    }
}

// MARK: - Brand

/// Wordmark: a tiny ensō with a vermilion seal tucked against it.
private struct SidebarBrand: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Enso(progress: isHovering ? 1 : 0.86, lineWidth: 2.6, color: Theme.ink)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(isHovering ? 40 : 0))
                Circle().fill(Theme.accent).frame(width: 4, height: 4)
            }
            .animation(.easeInOut(duration: 0.9), value: isHovering)
            Text("Vibease")
                .font(.serif(17, .bold))
                .foregroundStyle(Theme.ink)
            SealStamp(text: "乐", size: 15)
                .rotationEffect(.degrees(-6))
                .offset(y: -1)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vibease Music")
    }
}

private struct SidebarSectionTitle: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.serif(11, .medium))
            .tracking(2)
            .foregroundStyle(Theme.ink.opacity(0.42))
    }
}

// MARK: - Account chip

private struct AccountChip: View {
    let profile: UserProfile
    let avatarImage: NSImage?

    @Environment(AccountStore.self) private var account
    @State private var showPopover = false
    @State private var isHovering = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 8) {
                avatar(diameter: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.nickname)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if profile.vipType > 0 {
                        Text("黑胶 VIP")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.gold)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
                    .fill(isHovering ? Theme.wash : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) { isHovering = hovering }
        }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            accountCard
        }
    }

    @ViewBuilder
    private func avatar(diameter: CGFloat) -> some View {
        if let avatarImage {
            Image(nsImage: avatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: diameter - 2))
                .foregroundStyle(.tertiary)
                .frame(width: diameter, height: diameter)
        }
    }

    private var accountCard: some View {
        VStack(spacing: 12) {
            avatar(diameter: 56)
                .overlay {
                    Enso(lineWidth: 2.5, color: Theme.ink.opacity(0.7))
                        .frame(width: 74, height: 74)
                }
                .padding(.top, 6)
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.nickname)
                        .font(.serif(15, .bold))
                    if profile.vipType > 0 {
                        VIPBadge()
                    }
                }
                if let signature = profile.signature, !signature.isEmpty {
                    Text(signature)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            Rectangle().fill(Theme.hairline).frame(height: 0.75)
            Button {
                showPopover = false
                Task { await account.logout() }
            } label: {
                Text("退出登录")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.inkOutline)
        }
        .padding(16)
        .frame(width: 220)
    }
}

// MARK: - Rows

/// Selection is a pale ink brush mark swept in behind the row, with a single
/// vermilion dot where the brush landed.
private struct SidebarSelection: View {
    let isSelected: Bool
    let isHovering: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
                .fill(isHovering && !isSelected ? Theme.wash : .clear)
            PaintedBrush(painted: isSelected, color: Theme.ink.opacity(0.085))
                .padding(.vertical, 1)
            Circle()
                .fill(Theme.accent)
                .frame(width: 4, height: 4)
                .offset(x: -1)
                .scaleEffect(isSelected ? 1 : 0.01)
                .opacity(isSelected ? 1 : 0)
                .animation(AppAnimation.bouncy.delay(isSelected ? 0.18 : 0), value: isSelected)
        }
        .animation(AppAnimation.quick, value: isHovering)
    }
}

private struct SidebarRow: View {
    let title: LocalizedStringKey
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    let onDoubleClick: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .medium : .light))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.ink.opacity(0.62))
                    .frame(width: 18)
                    .symbolEffect(.bounce, value: isSelected)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.ink.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SidebarSelection(isSelected: isSelected, isHovering: isHovering))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleClick?() })
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 6))
    }
}

private struct SidebarPlaylistRow: View {
    let playlist: PlaylistSummary
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                CachedAsyncImage(url: playlist.coverURL?.resizedImageURL(64), animated: false)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5))
                    .saturation(isSelected || isHovering ? 1 : 0.75)
                Text(playlist.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.ink.opacity(0.78))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(SidebarSelection(isSelected: isSelected, isHovering: isHovering))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(AppAnimation.quick, value: isHovering)
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 6))
    }
}
