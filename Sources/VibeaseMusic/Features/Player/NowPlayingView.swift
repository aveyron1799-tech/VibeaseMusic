import SwiftUI

/// Immersive now-playing page: the artwork sits like a moon inside an ensō
/// that is brushed around it as the song plays; lyrics are set in Songti and
/// fade like ink the further they are from the current line.
struct NowPlayingView: View {
    let onNavigate: (Destination) -> Void

    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(SettingsManager.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var artworkImage: NSImage?
    @State private var colors: ArtworkColors = .fallback
    @State private var hasArtworkColors = false
    @State private var activeIndex: Int?
    @State private var isUserScrolling = false
    @State private var resumeTask: Task<Void, Never>?
    @State private var playPresses = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            backdrop

            HStack(spacing: 0) {
                leftColumn
                    .frame(maxWidth: .infinity)
                if hasLyricsColumn {
                    lyricsColumn
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
        }
        .overlay(alignment: .topLeading) {
            Button {
                close()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .compatGlass(interactive: true, in: Circle())
            }
            .buttonStyle(.pressable)
            .help("收起")
            .padding(.top, 40)
            .padding(.leading, 24)
        }
        .ignoresSafeArea()
        .task(id: player.currentTrack?.id) {
            await loadArtwork()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) { appeared = true }
        }
        .onExitCommand {
            close()
        }
    }

    private var hasLyricsColumn: Bool {
        player.hasCurrentTrack
    }

    private func close() {
        player.showNowPlaying = false
    }

    // MARK: - Backdrop

    /// Plain paper with the artwork's colour bleeding in like watercolour,
    /// and faint distant mountains along the bottom edge.
    private var backdrop: some View {
        ZStack(alignment: .bottom) {
            PaperBackground(wash: hasArtworkColors ? colors.primary : nil)
            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 900, height: 900)
                    .blur(radius: 120)
                    .opacity(0.14)
                    .blendMode(.multiply)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: -260, y: -260)
                    .clipped()
                    .allowsHitTesting(false)
            }
            InkMountains(seed: Double(player.currentTrack?.id ?? 7).truncatingRemainder(dividingBy: 9) + 0.5)
                .frame(height: 170)
                .opacity(0.8)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: colors)
    }

    private func loadArtwork() async {
        guard let urlString = player.currentTrack?.album.picUrl,
              let url = urlString.resizedImageURL(768) else {
            artworkImage = nil
            colors = .fallback
            hasArtworkColors = false
            return
        }
        let image = await ImageCache.shared.image(for: url)
        guard !Task.isCancelled else { return }
        artworkImage = image
        if let image {
            colors = ArtworkPalette.extract(from: image, cacheKey: urlString)
            hasArtworkColors = true
        } else {
            colors = .fallback
            hasArtworkColors = false
        }
    }

    // MARK: - Left column

    private var playbackFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.progress / player.duration, 0), 1)
    }

    private var artwork: some View {
        let diameter: CGFloat = 292
        return ZStack {
            Circle()
                .stroke(Theme.ink.opacity(0.1), lineWidth: 0.75)
                .frame(width: diameter + 52, height: diameter + 52)
            Enso(progress: max(playbackFraction, 0.004), lineWidth: 9, color: Theme.ink.opacity(0.82))
                .frame(width: diameter + 70, height: diameter + 70)
                .animation(.linear(duration: 0.5), value: playbackFraction)
            Group {
                if let artworkImage {
                    Image(nsImage: artworkImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Circle()
                        .fill(Theme.wash)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 44, weight: .ultraLight))
                                .foregroundStyle(Theme.ink.opacity(0.3))
                        )
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            .shadow(color: Theme.shadow.opacity(1.4), radius: 24, y: 14)
            // Paused: colours drain a little and the moon settles.
            .saturation(player.isPlaying ? 1 : 0.35)
            .scaleEffect(player.isPlaying ? 1 : 0.96)
            .animation(.easeInOut(duration: 0.9), value: player.isPlaying)
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
        .opacity(appeared || reduceMotion ? 1 : 0)
    }

    private var leftColumn: some View {
        VStack(spacing: 30) {
            Spacer()

            artwork

            if let track = player.currentTrack {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        if track.album.id > 0 {
                            navigationButton(track.name, destination: .album(track.album.id),
                                             font: .serif(25, .bold), color: Theme.ink)
                                .help("打开专辑：\(track.album.name)")
                        } else {
                            Text(track.name)
                                .font(.serif(25, .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                        }
                        if track.fee == 1 { VIPBadge() }
                    }
                    HStack(spacing: 4) {
                        ForEach(Array(track.artists.enumerated()), id: \.offset) { index, artist in
                            if index > 0 {
                                Text("/").foregroundStyle(Theme.ink.opacity(0.3))
                            }
                            if artist.id > 0 {
                                navigationButton(artist.name, destination: .artist(artist.id),
                                                 font: .system(size: 13), color: Theme.ink.opacity(0.62))
                                    .help("打开歌手：\(artist.name)")
                            } else {
                                Text(artist.name)
                                    .foregroundStyle(Theme.ink.opacity(0.6))
                            }
                        }
                        if track.album.id > 0 {
                            Text("·").foregroundStyle(Theme.accent)
                            navigationButton(track.album.name, destination: .album(track.album.id),
                                             font: .system(size: 13), color: Theme.ink.opacity(0.62))
                                .help("打开专辑：\(track.album.name)")
                        }
                    }
                    .font(.system(size: 13))
                    .lineLimit(1)
                }
                .frame(maxWidth: 420)
                .id(track.id)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }

            VStack(spacing: 18) {
                NowPlayingScrubber()
                    .frame(maxWidth: 360)
                controls
            }

            Spacer()
        }
        .padding(.trailing, hasLyricsColumn ? 30 : 0)
        .animation(.easeOut(duration: 0.5), value: player.currentTrack?.id)
    }

    private func navigationButton(_ title: String, destination: Destination,
                                  font: Font, color: Color) -> some View {
        Button {
            onNavigate(destination)
        } label: {
            Text(title)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            if let track = player.currentTrack {
                LikeButton(trackID: track.id, size: 15, diameter: 40)
            }

            if player.isFMMode {
                circleButton(icon: "trash", size: 14, help: "不喜欢，换一首") {
                    player.fmTrash()
                }
            } else {
                circleButton(icon: "backward.fill", size: 15, help: "上一首") {
                    player.previous()
                }
            }

            Button {
                playPresses += 1
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.inkFill)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.shadow.opacity(1.3), radius: 12, y: 6)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.onInk)
                        .offset(x: player.isPlaying ? 0 : 2)
                        .contentTransition(.symbolEffect(.replace))
                }
                .inkBloom(trigger: playPresses, color: Theme.ink, scale: 2.4)
            }
            .buttonStyle(.pressable)
            .help(player.isPlaying ? "暂停" : "播放")

            circleButton(icon: "forward.fill", size: 15, help: "下一首") {
                player.next()
            }

            if player.isFMMode {
                Image(systemName: "wind")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accent.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .help("私人漫游中")
            } else {
                circleButton(
                    icon: player.shuffleEnabled ? "shuffle" : (player.repeatMode == .one ? "repeat.1" : "repeat"),
                    size: 14,
                    tint: player.shuffleEnabled || player.repeatMode != .off ? Theme.accent : nil,
                    help: "播放模式"
                ) {
                    if player.shuffleEnabled {
                        player.toggleShuffle()
                    } else {
                        player.cycleRepeatMode()
                    }
                }
            }
        }
    }

    private func circleButton(icon: String, size: CGFloat, tint: Color? = nil,
                              help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint ?? Theme.ink.opacity(0.75))
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.14), lineWidth: 0.75))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .help(help)
    }

    // MARK: - Lyrics column

    @ViewBuilder
    private var lyricsColumn: some View {
        if let lyrics = player.lyrics, !lyrics.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        Color.clear.frame(height: 200)
                        ForEach(lyrics.lines) { line in
                            bigLyricLine(line, isActive: line.id == activeIndex)
                                .id(line.id)
                        }
                        Color.clear.frame(height: 240)
                    }
                    .padding(.horizontal, 24)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.16),
                            .init(color: .black, location: 0.82),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .onAppear {
                    activeIndex = lyrics.activeIndex(at: player.progress + 0.2)
                    if let activeIndex { proxy.scrollTo(activeIndex, anchor: .center) }
                }
                .onChange(of: player.progress) {
                    let index = lyrics.activeIndex(at: player.progress + 0.2)
                    guard index != activeIndex else { return }
                    activeIndex = index
                    guard !isUserScrolling, let index else { return }
                    withAnimation(.spring(response: 0.9, dampingFraction: 0.88)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
                .onChange(of: player.currentTrack?.id) {
                    activeIndex = nil
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
            quietState(text: "纯音乐，请静心聆听")
        } else if player.lyrics == nil {
            InkLoader(size: 40, color: Theme.ink.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            quietState(text: "此曲无词，留白亦是诗")
        }
    }

    private func quietState(text: String) -> some View {
        VStack(spacing: 16) {
            Enso(lineWidth: 4, color: Theme.ink.opacity(0.35))
                .frame(width: 70, height: 70)
            Text(text)
                .font(.serif(16))
                .tracking(3)
                .foregroundStyle(Theme.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bigLyricLine(_ line: LyricLine, isActive: Bool) -> some View {
        // Before the first line is reached everything stays legible.
        let distance = activeIndex.map { abs(line.id - $0) } ?? 0
        let resting = activeIndex == nil ? 0.55 : max(0.14, 0.42 - Double(distance) * 0.06)
        let blur = isActive || isUserScrolling || activeIndex == nil ? 0 : min(Double(distance) * 0.4, 2)
        return Button {
            player.seek(to: line.time)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(line.text.isEmpty ? "……" : line.text)
                        .font(.serif(isActive ? 27 : 21, isActive ? .bold : .medium))
                        .foregroundStyle(Theme.ink.opacity(isActive ? 1 : resting))
                }
                if settings.showLyricsTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: isActive ? 15 : 13.5))
                        .foregroundStyle(Theme.ink.opacity(isActive ? 0.62 : resting * 0.8))
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                // A vermilion tick marks the line being sung.
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 3, height: isActive ? 20 : 0)
                    .offset(x: -16)
                    .opacity(isActive ? 1 : 0)
            }
            .contentShape(Rectangle())
            .blur(radius: blur)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: isActive)
        .animation(.easeOut(duration: 0.5), value: distance)
    }
}

// MARK: - Scrubber

struct NowPlayingScrubber: View {
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
        VStack(spacing: 7) {
            GeometryReader { geo in
                let width = geo.size.width
                let lineHeight: CGFloat = isHovering || isDragging ? 3 : 1.5
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.12))
                        .frame(height: lineHeight)
                    Capsule()
                        .fill(Theme.ink.opacity(0.8))
                        .frame(width: max(lineHeight, width * fraction), height: lineHeight)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .offset(x: width * fraction - thumbDiameter / 2)
                }
                .frame(maxHeight: .infinity)
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

            HStack {
                Text(Formatters.duration(isDragging ? dragProgress : player.progress))
                Spacer()
                Text(Formatters.duration(player.duration))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(Theme.ink.opacity(0.45))
        }
        .onDisappear {
            if isDragging {
                isDragging = false
                player.isScrubbing = false
            }
        }
        .animation(AppAnimation.quick, value: isHovering)
    }

    private var thumbDiameter: CGFloat {
        isDragging ? 12 : (isHovering ? 10 : 6)
    }
}
