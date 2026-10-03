import SwiftUI

/// 私人漫游 — immersive personal FM page.
struct FMView: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(\.openLogin) private var openLogin
    @State private var playPresses = 0

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

    /// Mountains drifting past very slowly, as if seen from a boat.
    private var backdrop: some View {
        ZStack(alignment: .bottom) {
            PaperBackground()
            if let cover = track?.album.picUrl?.resizedImageURL(128) {
                ArtworkWash(url: cover, height: 600)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            TimelineView(.animation(minimumInterval: 1 / 15, paused: !(player.isPlaying && player.isFMMode))) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                GeometryReader { geo in
                    let width = max(geo.size.width, 1)
                    let drift = CGFloat((t * 6).truncatingRemainder(dividingBy: Double(width)))
                    // Ridgelines meet the baseline at both ends, so two copies tile seamlessly.
                    HStack(spacing: 0) {
                        InkMountains(seed: 2.3).frame(width: width, height: 200)
                        InkMountains(seed: 2.3).frame(width: width, height: 200)
                    }
                    .offset(x: -drift)
                }
                .frame(height: 200)
            }
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .leading, endPoint: .trailing))
        }
        .ignoresSafeArea()
        .animation(AppAnimation.smooth, value: track?.id)
    }

    // MARK: - Content

    private func content(coverSize: CGFloat) -> some View {
        VStack(spacing: 28) {
            ZStack {
                Enso(lineWidth: 7, color: Theme.ink.opacity(track == nil ? 0.35 : 0.8), startAngle: -80)
                    .frame(width: coverSize + 56, height: coverSize + 56)
                if let cover = track?.album.picUrl?.resizedImageURL(768) {
                    CachedAsyncImage(url: cover)
                        .frame(width: coverSize, height: coverSize)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                        .shadow(color: Theme.shadow.opacity(1.3), radius: 22, y: 12)
                        .saturation(player.isPlaying && player.isFMMode ? 1 : 0.4)
                        .id(track?.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    Image(systemName: "wind")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(Theme.ink.opacity(0.35))
                        .frame(width: coverSize, height: coverSize)
                }
            }
            .scaleEffect(player.isPlaying && player.isFMMode ? 1 : 0.96)
            .animation(.easeInOut(duration: 0.9), value: player.isPlaying && player.isFMMode)
            .animation(.easeInOut(duration: 0.6), value: track?.id)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(track?.name ?? String(localized: "私人漫游"))
                        .font(.serif(25, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if track?.fee == 1 {
                        VIPBadge()
                    }
                }
                Text(track?.artistNames ?? String(localized: "随心而行，一曲一山"))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(maxWidth: 420)

            if player.isFMMode {
                controls
            } else {
                Button {
                    player.startFM()
                } label: {
                    Label("开始漫游", systemImage: "wind")
                }
                .buttonStyle(.ink)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            fmButton(icon: "hand.thumbsdown", help: "不喜欢，换一首") { player.fmTrash() }

            Button {
                playPresses += 1
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 62, height: 62)
                        .shadow(color: Theme.shadow.opacity(1.3), radius: 12, y: 6)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.onInk)
                        .offset(x: player.isPlaying ? 0 : 2)
                        .contentTransition(.symbolEffect(.replace))
                }
                .inkBloom(trigger: playPresses, color: Theme.ink, scale: 2.4)
            }
            .buttonStyle(.pressable)

            fmButton(icon: "forward.fill", help: "下一首") { player.fmNext() }

            if let track {
                LikeButton(trackID: track.id, size: 16, diameter: 46)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.14), lineWidth: 0.75))
            }
        }
    }

    private func fmButton(icon: String, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.14), lineWidth: 0.75))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .help(help)
    }

    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Enso(lineWidth: 5, color: Theme.ink.opacity(0.55))
                .frame(width: 90, height: 90)
                .overlay(Image(systemName: "wind").font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.ink.opacity(0.5)))
            Text("登录后开启私人漫游")
                .font(.serif(18, .bold))
                .foregroundStyle(Theme.ink)
            Text("网易云会根据你的听歌口味推荐音乐")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink.opacity(0.55))
            Button("登录") { openLogin() }
                .buttonStyle(.ink)
        }
    }
}
