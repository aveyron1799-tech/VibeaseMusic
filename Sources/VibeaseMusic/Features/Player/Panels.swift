import SwiftUI

// MARK: - Lyrics panel

struct LyricsPanel: View {
    @Environment(PlayerService.self) private var player
    @Environment(SettingsManager.self) private var settings

    @State private var activeIndex: Int?
    @State private var isUserScrolling = false
    @State private var resumeTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 0.75).padding(.horizontal, 16)
            content
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .panelChrome()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                PanelTitle(text: "歌词")
                if let contributor = player.lyrics?.contributor {
                    Text("贡献者：\(contributor)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            PanelCloseButton { player.activePanel = nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        if let lyrics = player.lyrics, !lyrics.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 120)
                        ForEach(lyrics.lines) { line in
                            lyricLine(line, isActive: line.id == activeIndex)
                                .id(line.id)
                        }
                        Color.clear.frame(height: 160)
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: player.progress) {
                    let index = lyrics.activeIndex(at: player.progress + 0.2)
                    guard index != activeIndex else { return }
                    activeIndex = index
                    guard !isUserScrolling, let index else { return }
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
                .onChange(of: player.currentTrack?.id) {
                    activeIndex = nil
                    proxy.scrollTo(0, anchor: .top)
                }
                .onAppear {
                    activeIndex = lyrics.activeIndex(at: player.progress + 0.2)
                    if let activeIndex { proxy.scrollTo(activeIndex, anchor: .center) }
                }
                .onScrollPhaseChange { _, phase in
                    // Wheel and trackpad scrolling don't produce drag gestures on macOS.
                    if phase == .interacting || phase == .decelerating {
                        isUserScrolling = true
                        resumeTask?.cancel()
                    } else if phase == .idle, isUserScrolling {
                        resumeTask?.cancel()
                        resumeTask = Task {
                            try? await Task.sleep(for: .seconds(3))
                            guard !Task.isCancelled else { return }
                            isUserScrolling = false
                        }
                    }
                }
            }
        } else if player.lyrics?.isInstrumental == true {
            EmptyStateView(icon: "music.quarternote.3", title: "纯音乐", subtitle: "请欣赏")
        } else if player.lyrics == nil, player.hasCurrentTrack {
            VStack(spacing: 12) {
                InkLoader(size: 28, color: Theme.ink.opacity(0.6))
                Text("歌词加载中…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if player.hasCurrentTrack {
            EmptyStateView(icon: "quote.bubble", title: "暂无歌词",
                           subtitle: "这首歌曲没有可用歌词")
        } else {
            EmptyStateView(icon: "quote.bubble", title: "暂无歌词")
        }
    }

    private func lyricLine(_ line: LyricLine, isActive: Bool) -> some View {
        Button {
            player.seek(to: line.time)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.text.isEmpty ? "……" : line.text)
                    .font(.serif(isActive ? 16.5 : 14, isActive ? .bold : .regular))
                    .foregroundStyle(Theme.ink.opacity(isActive ? 1 : 0.45))
                if settings.showLyricsTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: isActive ? 13 : 12))
                        .foregroundStyle(isActive ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2.5, height: isActive ? 14 : 0)
                    .offset(x: -11)
                    .opacity(isActive ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Queue panel

struct QueuePanel: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 0.75).padding(.horizontal, 16)
            if let current = player.currentTrack {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        sectionLabel("正在播放")
                        QueueRow(track: current, isCurrent: true)

                        if player.isFMMode, !player.fmPlayedTracks.isEmpty {
                            sectionLabel("本次漫游已播放")
                                .padding(.top, 10)
                            ForEach(player.fmPlayedTracks, id: \.id) { track in
                                QueueRow(track: track, isCurrent: false, isHistory: true)
                            }
                        }

                        if !player.upcomingTracks.isEmpty {
                            sectionLabel("即将播放")
                                .padding(.top, 10)
                            ForEach(Array(player.upcomingTracks.prefix(100).enumerated()),
                                    id: \.offset) { _, track in
                                QueueRow(track: track, isCurrent: false)
                            }
                        }
                    }
                    .padding(10)
                }
            } else {
                EmptyStateView(icon: "list.bullet", title: "播放队列是空的",
                               subtitle: "播放一些音乐吧")
            }
        }
        .frame(width: 340)
        .frame(maxHeight: .infinity)
        .panelChrome()
    }

    private var header: some View {
        HStack {
            PanelTitle(text: "播放队列")
            Text("\(player.upcomingTracks.count + (player.hasCurrentTrack ? 1 : 0) + (player.isFMMode ? player.fmPlayedTracks.count : 0)) 首")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            PanelCloseButton { player.activePanel = nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.serif(11, .medium))
            .tracking(2)
            .foregroundStyle(Theme.ink.opacity(0.42))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}

private struct QueueRow: View {
    let track: Track
    let isCurrent: Bool
    var isHistory = false

    @Environment(PlayerService.self) private var player
    @State private var isHovering = false

    var body: some View {
        Button {
            guard !isCurrent else { return }
            player.jumpTo(track)
        } label: {
            HStack(spacing: 10) {
                CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(96), animated: false)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5))
                    .saturation(isHistory ? 0.3 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(isCurrent ? Theme.accent : Theme.ink.opacity(isHistory ? 0.5 : 0.92))
                        .lineLimit(1)
                    Text(track.artistNames)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    PlayingIndicator(animating: player.isPlaying)
                } else if isHovering && !isHistory {
                    Button {
                        player.removeFromUpcoming(track)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.5))
                    }
                    .buttonStyle(.pressable)
                } else {
                    Text(Formatters.duration(track.duration))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(Theme.ink.opacity(0.38))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.interactiveRow)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Panel chrome

private struct PanelTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(text)
                .font(.serif(16, .bold))
                .foregroundStyle(Theme.ink)
            Circle().fill(Theme.accent).frame(width: 4, height: 4)
        }
    }
}

private struct PanelCloseButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .frame(width: 24, height: 24)
                .background(Circle().fill(isHovering ? Theme.wash : .clear))
                .rotationEffect(.degrees(isHovering ? 90 : 0))
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(AppAnimation.spring, value: isHovering)
        .help("关闭")
    }
}

extension View {
    /// Side panels are a single tall sheet laid on the page.
    func panelChrome() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            .compatGlass(interactive: true, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}
