import SwiftUI

struct PlayerBar: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account

    @State private var artworkHover = false
    @State private var playPresses = 0

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 860
            let sideWidth: CGFloat = compact ? 190 : 252
            HStack(spacing: 12) {
                songInfoSection
                    .frame(width: sideWidth, alignment: .leading)
                centerSection
                    .frame(maxWidth: .infinity)
                optionsSection(compact: compact)
                    .frame(width: sideWidth, alignment: .trailing)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: Theme.Layout.playerBarHeight)
        .compatGlass(interactive: true, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .background(alignment: .bottom) { bottomFade }
    }

    // MARK: - Left: artwork + titles + like

    private var songInfoSection: some View {
        HStack(spacing: 10) {
            artworkButton
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    MarqueeText(text: player.currentTrack?.name ?? String(localized: "未在播放"))
                        .frame(height: 17)
                        .help(player.currentTrack?.name ?? String(localized: "未在播放"))
                    if player.currentTrack?.fee == 1 {
                        VIPBadge()
                    }
                }
                Text(player.currentTrack?.artistNames ?? "静候一曲")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .lineLimit(1)
                    .help(player.currentTrack?.artistNames ?? "VibeaseMusic")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let track = player.currentTrack {
                LikeButton(trackID: track.id)
            }
        }
    }

    private var artworkButton: some View {
        Button {
            guard player.hasCurrentTrack else { return }
            withAnimation(AppAnimation.smooth) {
                player.showNowPlaying = true
            }
        } label: {
            ZStack {
                if player.hasCurrentTrack {
                    CachedAsyncImage(url: player.currentTrack?.album.picUrl?.resizedImageURL(128))
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 0.75)
                        )
                        .shadow(color: Theme.shadow, radius: 4, y: 2)
                } else {
                    Enso(lineWidth: 2.4, color: Theme.ink.opacity(0.4))
                        .frame(width: 34, height: 34)
                        .frame(width: 40, height: 40)
                }
            }
            .overlay(alignment: .topTrailing) {
                if player.hasCurrentTrack {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(artworkHover ? 0.35 : 0),
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                        .opacity(artworkHover ? 1 : 0)
                }
            }
            .onHover { artworkHover = $0 }
            .animation(AppAnimation.quick, value: artworkHover)
        }
        .buttonStyle(.pressable)
        .help("打开播放页")
    }

    // MARK: - Center: transport + scrubber

    private var centerSection: some View {
        VStack(spacing: 3) {
            HStack(spacing: 10) {
                if player.isFMMode {
                    PlayerIconButton(icon: "trash", size: 12) {
                        player.fmTrash()
                    }
                    .help("不喜欢，换一首")
                } else {
                    PlayerIconButton(
                        icon: "shuffle", size: 12,
                        isActive: player.shuffleEnabled
                    ) {
                        player.toggleShuffle()
                    }
                    .help("随机播放")
                }

                PlayerIconButton(icon: "backward.fill", size: 14, disabled: player.isFMMode) {
                    player.previous()
                }

                playPauseButton

                PlayerIconButton(icon: "forward.fill", size: 14) {
                    player.next()
                }

                if player.isFMMode {
                    Image(systemName: "wind")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26, height: 26)
                        .help("私人漫游中")
                } else {
                    PlayerIconButton(
                        icon: player.repeatMode == .one ? "repeat.1" : "repeat", size: 12,
                        isActive: player.repeatMode != .off
                    ) {
                        player.cycleRepeatMode()
                    }
                    .help("循环模式")
                }
            }
            ScrubberLane()
        }
        .padding(.vertical, 4)
        .opacity(player.hasCurrentTrack ? 1 : 0.5)
    }

    private var playPauseButton: some View {
        Button {
            playPresses += 1
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.inkFill)
                    .frame(width: 32, height: 32)
                    .shadow(color: Theme.shadow, radius: 4, y: 2)
                if player.isBuffering && player.isPlaying {
                    InkLoader(size: 16, color: Theme.onInk)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.onInk)
                        .offset(x: player.isPlaying ? 0 : 1)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .inkBloom(trigger: playPresses, color: Theme.ink, scale: 2.2)
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, 4)
    }

    // MARK: - Right: quality / panels / volume

    private func optionsSection(compact: Bool) -> some View {
        HStack(spacing: 7) {
            if !compact, let level = player.servedQuality,
               let quality = AudioQuality(rawValue: level) {
                QualityTag(text: quality.badge)
                    .padding(.trailing, 2)
            } else if !compact, player.unblockSource != nil {
                QualityTag(text: String(localized: "音源"))
                    .padding(.trailing, 2)
                    .help("来自 \(player.unblockSource ?? "")")
            }
            PlayerIconButton(
                icon: "quote.bubble", size: 13,
                isActive: player.activePanel == .lyrics
            ) {
                player.activePanel = player.activePanel == .lyrics ? nil : .lyrics
            }
            .help("歌词")
            PlayerIconButton(
                icon: "inset.filled.bottomthird.square", size: 13,
                isActive: SettingsManager.shared.showDesktopLyrics
            ) {
                SettingsManager.shared.showDesktopLyrics.toggle()
            }
            .help("桌面歌词")
            PlayerIconButton(
                icon: "list.bullet", size: 13,
                isActive: player.activePanel == .queue
            ) {
                player.activePanel = player.activePanel == .queue ? nil : .queue
            }
            .help("播放队列")
            VolumeControl()
        }
    }

    private var bottomFade: some View {
        LinearGradient(
            colors: [Theme.paper.opacity(0), Theme.paper.opacity(0.85)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 64)
        .padding(.horizontal, -16)
        .allowsHitTesting(false)
    }
}

// MARK: - Icon button

struct PlayerIconButton: View {
    let icon: String
    var size: CGFloat = 14
    var isActive = false
    var disabled = false
    var showsActiveDot = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isActive ? Theme.accent : Theme.ink.opacity(isHovering ? 0.95 : 0.72))
                .frame(width: 26, height: 26)
                .background(Circle().fill(isHovering && !disabled ? Theme.wash : .clear))
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 3, height: 3)
                        .offset(y: 2)
                        .opacity(isActive && showsActiveDot ? 1 : 0)
                        .scaleEffect(isActive ? 1 : 0.1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { isHovering = $0 }
        .animation(AppAnimation.quick, value: isHovering)
        .animation(AppAnimation.bouncy, value: isActive)
    }
}

// MARK: - Like button

/// Liking a song stamps it: the heart lands with a thud, vermilion ink blooms
/// beneath it, and a tiny 藏 ("kept") seal floats up and fades.
struct LikeButton: View {
    let trackID: Int
    var size: CGFloat = 13
    var restingColor: Color = Theme.ink.opacity(0.72)
    var diameter: CGFloat = 26

    @Environment(AccountStore.self) private var account
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamps = 0
    @State private var landing = false
    @State private var sealRising = false
    @State private var isHovering = false

    var body: some View {
        let liked = account.isLiked(trackID)
        Button {
            if !liked { stamp() }
            Task { await account.toggleLike(trackID: trackID) }
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(liked ? Theme.accent : restingColor)
                .scaleEffect(landing ? 1.45 : 1)
                .rotationEffect(.degrees(landing ? -12 : 0))
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(isHovering ? Theme.wash : .clear))
                .inkBloom(trigger: stamps, color: Theme.accent, scale: 2.6)
                .overlay {
                    SealStamp(text: "藏", size: 14)
                        .offset(y: sealRising ? -26 : -8)
                        .opacity(sealRising ? 0 : (stamps > 0 && landing ? 1 : 0))
                        .allowsHitTesting(false)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .onHover { isHovering = $0 }
        .animation(AppAnimation.quick, value: isHovering)
        .help(liked ? String(localized: "取消喜欢") : String(localized: "喜欢"))
    }

    private func stamp() {
        guard !reduceMotion else { return }
        stamps += 1
        sealRising = false
        landing = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) { landing = false }
        withAnimation(.easeOut(duration: 1.1).delay(0.05)) { sealRising = true }
    }
}

// MARK: - Scrubber

/// A hairline drawn in ink. The playhead is a vermilion dot that swells
/// while hovered; dragging shows the time on a small paper slip.
struct ScrubberLane: View {
    @Environment(PlayerService.self) private var player

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var fraction: Double {
        guard player.duration > 0 else { return 0 }
        let value = isDragging ? dragProgress : player.progress
        return min(max(value / player.duration, 0), 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            timeLabel(isDragging ? dragProgress : player.progress)
            track
            timeLabel(player.duration)
        }
        .frame(maxWidth: 460)
    }

    private func timeLabel(_ value: TimeInterval) -> some View {
        Text(Formatters.duration(value))
            .font(.system(size: 9.5).monospacedDigit())
            .foregroundStyle(Theme.ink.opacity(0.5))
            .frame(width: 34)
    }

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let lineHeight: CGFloat = isHovering || isDragging ? 3 : 1.5
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.ink.opacity(0.12))
                    .frame(height: lineHeight)
                Capsule()
                    .fill(Theme.ink.opacity(0.78))
                    .frame(width: max(lineHeight, width * fraction), height: lineHeight)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(color: Theme.accent.opacity(isDragging ? 0.45 : 0), radius: 4)
                    .offset(x: width * fraction - thumbDiameter / 2)
                    .opacity(player.hasCurrentTrack ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if isDragging {
                    Text(Formatters.duration(dragProgress))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .compatGlass(in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .fixedSize()
                        .offset(x: min(max(width * fraction - 18, -8), width - 28), y: -22)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard player.duration > 0 else { return }
                        isDragging = true
                        player.isScrubbing = true
                        dragProgress = min(max(value.location.x / width, 0), 1) * player.duration
                    }
                    .onEnded { _ in
                        defer {
                            isDragging = false
                            player.isScrubbing = false
                        }
                        guard isDragging else { return }
                        player.seek(to: dragProgress)
                    }
            )
        }
        .frame(height: 14)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) { isHovering = hovering }
        }
        .onDisappear {
            if isDragging {
                isDragging = false
                player.isScrubbing = false
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isDragging)
        .animation(AppAnimation.quick, value: isHovering)
    }

    private var thumbDiameter: CGFloat {
        isDragging ? 11 : (isHovering ? 9 : 5)
    }
}

// MARK: - Volume

struct VolumeControl: View {
    @Environment(PlayerService.self) private var player
    @State private var showPopover = false

    var body: some View {
        PlayerIconButton(icon: volumeIcon, size: 13) {
            showPopover.toggle()
        }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VolumeSlider()
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
        }
        .help("音量")
    }

    private var volumeIcon: String {
        switch player.volume {
        case 0: return "speaker.slash"
        case ..<0.4: return "speaker.wave.1"
        case ..<0.75: return "speaker.wave.2"
        default: return "speaker.wave.3"
        }
    }
}

struct VolumeSlider: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        @Bindable var player = player
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Theme.ink.opacity(0.12))
                    .frame(width: 3)
                Capsule()
                    .fill(Theme.ink.opacity(0.78))
                    .frame(width: 3, height: max(3, height * CGFloat(player.volume)))
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 9, height: 9)
                    .offset(y: -max(0, height * CGFloat(player.volume) - 4.5))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        player.volume = Float(min(max(1 - value.location.y / height, 0), 1))
                    }
            )
        }
        .frame(width: 22, height: 110)
    }
}
