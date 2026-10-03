// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI

/// 私人漫游 — immersive personal FM page.
struct ClassicFMView: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(\.openLogin) private var openLogin
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            Group {
                if account.hasAuthCookie {
                    content(coverSize: min(300, max(120, geometry.size.height - 200)))
                } else {
                    loginPrompt
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background { backdrop.frame(width: geometry.size.width, height: geometry.size.height).clipped() }
        }
        .navigationTitle("漫游")
        .toolbarBackgroundVisibility(.hidden, for: .automatic)
    }

    private var track: Track? {
        player.isFMMode ? player.currentTrack : nil
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let cover = track?.album.picUrl?.resizedImageURL(384) {
                CachedAsyncImage(url: cover)
                    .scaledToFill()
                    .blur(radius: 80)
                    .opacity(colorScheme == .dark ? 0.45 : 0.3)
                    .saturation(1.4)
            }
            LinearGradient(
                colors: [.clear, Color(nsColor: .windowBackgroundColor).opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(ClassicAnimation.smooth, value: track?.id)
    }

    // MARK: - Content

    private func content(coverSize: CGFloat) -> some View {
        VStack(spacing: 28) {

            ZStack {
                if let cover = track?.album.picUrl?.resizedImageURL(768) {
                    CachedAsyncImage(url: cover)
                        .frame(width: coverSize, height: coverSize)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.quaternary.opacity(0.4))
                        .frame(width: coverSize, height: coverSize)
                        .overlay(
                            Image(systemName: "wave.3.right.circle")
                                .font(.system(size: 56, weight: .light))
                                .foregroundStyle(.tertiary)
                        )
                }
            }
            .scaleEffect(player.isPlaying && player.isFMMode ? 1 : 0.94)
            .animation(ClassicAnimation.bouncy, value: player.isPlaying && player.isFMMode)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(track?.name ?? String(localized: "私人漫游"))
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(1)
                    if track?.fee == 1 {
                        ClassicVIPBadge()
                    }
                }
                Text(track?.artistNames ?? String(localized: "根据你的口味漫游好音乐"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 420)

            if player.isFMMode {
                controls
            } else {
                Button {
                    player.startFM()
                } label: {
                    Label("开始漫游", systemImage: "wave.3.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(ClassicTheme.accentGradient, in: Capsule())
                        .shadow(color: ClassicTheme.accent.opacity(0.35), radius: 10, y: 3)
                }
                .buttonStyle(.classicPressable)
            }

        }
        .padding(.horizontal, 40)
    }

    private var controls: some View {
        HStack(spacing: 26) {
            Button {
                player.fmTrash()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.classicPressable)
            .help("不喜欢，换一首")

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(ClassicTheme.accentGradient)
                        .frame(width: 64, height: 64)
                        .shadow(color: ClassicTheme.accent.opacity(0.4), radius: 12, y: 4)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.classicPressable)

            Button {
                player.fmNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.classicPressable)
            .help("下一首")

            if let track {
                ClassicLikeButton(trackID: track.id, size: 16)
                    .frame(width: 48, height: 48)
                    .background(.primary.opacity(0.06), in: Circle())
            }
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wave.3.right.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
            Text("登录后开启私人漫游")
                .font(.headline)
            Text("网易云会根据你的听歌口味推荐音乐")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("登录") { openLogin() }
                .buttonStyle(.borderedProminent)
                .tint(ClassicTheme.accent)
        }
    }
}
