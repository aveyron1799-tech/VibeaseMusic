import SwiftUI

// MARK: - Menu Bar Status Label

struct MenuBarStatusLabel: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        HStack(spacing: 4) {
            if player.isPlaying {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            } else {
                Image(systemName: "music.note")
            }
        }
    }
}

// MARK: - Menu Bar Player View

struct MenuBarPlayerView: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(SettingsManager.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            if let track = player.currentTrack {
                trackInfoSection(track: track)
                progressBarSection
                playbackControlsSection
                volumeControlSection
            } else {
                emptyStateSection
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 0.75)
                .padding(.horizontal, -14)

            bottomToolbarSection
        }
        .padding(14)
        .frame(width: 320)
        .foregroundStyle(Theme.ink)
        .background { PaperBackground().ignoresSafeArea() }
    }

    // MARK: - Track Info

    private func trackInfoSection(track: Track) -> some View {
        HStack(spacing: 10) {
            CoverArtwork(url: track.album.picUrl?.resizedImageURL(128), size: 46,
                         cornerRadius: Theme.Radius.small)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(track.name)
                        .font(.serif(14, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if track.fee == 1 {
                        VIPBadge()
                    }
                }

                Text(track.artistNames)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LikeButton(trackID: track.id, size: 14)
        }
    }

    // MARK: - Progress Bar

    private var progressBarSection: some View {
        VStack(spacing: 4) {
            MenuBarScrubber()
            HStack {
                Text(Formatters.duration(player.progress))
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.5))
                Spacer()
                Text(Formatters.duration(player.duration))
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControlsSection: some View {
        HStack(spacing: 16) {
            // Shuffle
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(player.shuffleEnabled ? Theme.accent : Theme.ink.opacity(0.55))
            }
            .buttonStyle(.pressable)
            .help("随机播放")

            // Previous
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .disabled(!player.hasCurrentTrack)
            .help("上一首")

            // Play / Pause
            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 34, height: 34)
                        .shadow(color: Theme.shadow, radius: 4, y: 2)

                    if player.isBuffering && player.isPlaying {
                        InkLoader(size: 16, color: Theme.onInk)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.onInk)
                            .offset(x: player.isPlaying ? 0 : 1)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.pressable)
            .disabled(!player.hasCurrentTrack)
            .help(player.isPlaying ? "暂停" : "播放")

            // Next
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.85))
            }
            .buttonStyle(.pressable)
            .disabled(!player.hasCurrentTrack)
            .help("下一首")

            // Repeat
            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(player.repeatMode != .off ? Theme.accent : Theme.ink.opacity(0.55))
            }
            .buttonStyle(.pressable)
            .help("循环模式")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Volume Control

    private var volumeControlSection: some View {
        @Bindable var player = player
        return HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.55))
                .frame(width: 14)

            Slider(value: Binding(
                get: { Double(player.volume) },
                set: { player.volume = Float($0) }
            ), in: 0...1)
            .tint(Theme.ink.opacity(0.78))
            .controlSize(.mini)

            Text("\(Int(player.volume * 100))%")
                .font(.system(size: 9.5).monospacedDigit())
                .foregroundStyle(Theme.ink.opacity(0.5))
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 2)
    }

    private var volumeIcon: String {
        switch player.volume {
        case 0: return "speaker.slash.fill"
        case ..<0.4: return "speaker.wave.1.fill"
        case ..<0.75: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Enso(lineWidth: 3.5, color: Theme.ink.opacity(0.35))
                    .frame(width: 58, height: 58)
                Image(systemName: "music.note")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
            Text("暂无播放中的歌曲")
                .font(.serif(14, .bold))
                .foregroundStyle(Theme.ink.opacity(0.8))

            HStack(spacing: 10) {
                Button("私人漫游") {
                    player.startFM()
                }
                .buttonStyle(.inkOutline)

                Button("打开主界面") {
                    WindowManager.showMainWindow()
                }
                .buttonStyle(.ink)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbarSection: some View {
        HStack(spacing: 12) {
            Button {
                WindowManager.showMainWindow()
            } label: {
                Label("打开主界面", systemImage: "macwindow")
                    .font(.system(size: 11))
            }
            .buttonStyle(.pressable)
            .foregroundStyle(Theme.ink.opacity(0.8))

            Spacer()

            Button {
                settings.showDesktopLyrics.toggle()
            } label: {
                Label("桌面歌词", systemImage: settings.showDesktopLyrics ? "text.badge.checkmark" : "text.bubble")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.showDesktopLyrics ? Theme.accent : Theme.ink.opacity(0.55))
            }
            .buttonStyle(.pressable)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            .buttonStyle(.pressable)
            .help("退出 VibeaseMusic")
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Menu Bar Scrubber

private struct MenuBarScrubber: View {
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
        GeometryReader { geo in
            let width = geo.size.width
            let lineHeight: CGFloat = isHovering || isDragging ? 3 : 1.5
            let thumb: CGFloat = isHovering || isDragging ? 8 : 5
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.ink.opacity(0.12))
                    .frame(height: lineHeight)

                Capsule()
                    .fill(Theme.ink.opacity(0.78))
                    .frame(width: max(0, width * CGFloat(fraction)), height: lineHeight)

                Circle()
                    .fill(Theme.accent)
                    .frame(width: thumb, height: thumb)
                    .offset(x: width * CGFloat(fraction) - thumb / 2)
                    .opacity(player.hasCurrentTrack ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(AppAnimation.quick, value: isHovering || isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard player.duration > 0 else { return }
                        isDragging = true
                        let pct = min(max(value.location.x / width, 0), 1)
                        dragProgress = Double(pct) * player.duration
                    }
                    .onEnded { value in
                        guard player.duration > 0 else { return }
                        let pct = min(max(value.location.x / width, 0), 1)
                        player.seek(to: Double(pct) * player.duration)
                        isDragging = false
                    }
            )
        }
        .frame(height: 10)
    }
}
