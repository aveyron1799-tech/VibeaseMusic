import SwiftUI

struct DailySongsView: View {
    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                    .padding(.horizontal, Theme.Layout.contentInset)
                    .padding(.top, 22)

                if isLoading {
                    InkLoader(size: 40, color: Theme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                    .frame(minHeight: 300)
                } else if tracks.isEmpty {
                    EmptyStateView(icon: "calendar.badge.clock", title: "暂无每日推荐",
                                   subtitle: "多听几首歌培养口味，每天 6:00 更新")
                        .frame(minHeight: 300)
                } else {
                    TrackListView(tracks: tracks, source: .daily)
                        .padding(.horizontal, Theme.Layout.contentInset - 10)
                }
                Color.clear.frame(height: 8)
            }
        }
        .background(alignment: .top) {
            ArtworkWash(url: tracks.first?.album.picUrl?.resizedImageURL(128))
                .ignoresSafeArea()
        }
        .hoverScrollIndicators()
        .navigationTitle("每日推荐")
        .task(id: account.sessionVersion) {
            tracks = []
            await load()
        }
    }

    /// A dated letter (笺): the day in large Songti numerals, the month
    /// stamped beside it, and the first few covers fanned like cards.
    private var header: some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: .now)
        let month = calendar.component(.month, from: .now)
        return HStack(alignment: .bottom, spacing: 26) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(day)")
                    .font(.serif(96, .bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                SealStamp(text: ChineseDate.numeral(month) + "月", size: 26, vertical: true)
                    .rotationEffect(.degrees(-3))
                    .padding(.top, 18)
            }
            .frame(height: 120, alignment: .bottom)

            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: ChineseDate.string(for: .now))
                Text("每日推荐")
                    .font(.serif(29, .bold))
                    .foregroundStyle(Theme.ink)
                Text("依你的口味而选 · 每天 6:00 更新")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink.opacity(0.5))
                Button {
                    player.play(tracks: tracks, source: .daily)
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                }
                .buttonStyle(.ink)
                .disabled(tracks.isEmpty)
                .padding(.top, 6)
            }

            Spacer(minLength: 0)

            FannedCovers(urls: tracks.prefix(4).compactMap { $0.album.picUrl?.resizedImageURL(256) })
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 0.75)
        }
    }

    private func load() async {
        let version = account.sessionVersion
        guard account.isLoggedIn else {
            isLoading = false
            errorMessage = String(localized: "登录后才能查看每日推荐")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await NeteaseAPI.dailyRecommendSongs()
            guard !Task.isCancelled, version == account.sessionVersion else { return }
            tracks = result
            isLoading = false
        } catch {
            guard !Task.isCancelled, version == account.sessionVersion else { return }
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

/// Covers held like a hand of cards; hovering spreads them.
private struct FannedCovers: View {
    let urls: [URL]
    @State private var isHovering = false

    var body: some View {
        ZStack {
            ForEach(Array(urls.enumerated().reversed()), id: \.offset) { index, url in
                let spread = Double(index) - Double(urls.count - 1) / 2
                CoverArtwork(url: url, size: 110, lifted: isHovering)
                    .rotationEffect(.degrees(spread * (isHovering ? 9 : 4)), anchor: .bottom)
                    .offset(x: spread * (isHovering ? 46 : 20), y: abs(spread) * (isHovering ? 8 : 3))
            }
        }
        .frame(width: 260, height: 140)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isHovering)
        .accessibilityHidden(true)
    }
}
