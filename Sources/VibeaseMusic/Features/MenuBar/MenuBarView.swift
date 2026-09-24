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

            Divider()
                .padding(.horizontal, -12)

            bottomToolbarSection
        }
        .padding(14)
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    // MARK: - Track Info

    private func trackInfoSection(track: Track) -> some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: track.album.picUrl?.resizedImageURL(128)) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary)
                    Image(systemName: "music.note")
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(track.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if track.fee == 1 {
                        VIPBadge()
                    }
                }

                Text(track.artistNames)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatters.duration(player.duration))
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(player.shuffleEnabled ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .help("随机播放")

            // Previous
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasCurrentTrack)
            .help("上一首")

            // Play / Pause
            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 4, y: 1)

                    if player.isBuffering && player.isPlaying {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .scaleEffect(0.65)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!player.hasCurrentTrack)
            .help(player.isPlaying ? "暂停" : "播放")

            // Next
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasCurrentTrack)
            .help("下一首")

            // Repeat
            Button {
                player.cycleRepeatMode()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(player.repeatMode != .off ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
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
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Slider(value: Binding(
                get: { Double(player.volume) },
                set: { player.volume = Float($0) }
            ), in: 0...1)
            .tint(Theme.accent)
            .controlSize(.mini)

            Text("\(Int(player.volume * 100))%")
                .font(.system(size: 9.5).monospacedDigit())
                .foregroundStyle(.secondary)
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
        VStack(spacing: 8) {
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("暂无播放中的歌曲")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("私人漫游") {
                    player.startFM()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Theme.accent)

                Button("打开主界面") {
                    WindowManager.showMainWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Theme.accent)
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
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Button {
                settings.showDesktopLyrics.toggle()
            } label: {
                Label("桌面歌词", systemImage: settings.showDesktopLyrics ? "text.badge.checkmark" : "text.bubble")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.showDesktopLyrics ? Theme.accent : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("退出 VibeaseMusic")
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Menu Bar Scrubber

private struct MenuBarScrubber: View {
    @Environment(PlayerService.self) private var player
    @Environment(\.colorScheme) private var colorScheme

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
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12))
                    .frame(height: 3.5)

                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, width * CGFloat(fraction)), height: 3.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
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
