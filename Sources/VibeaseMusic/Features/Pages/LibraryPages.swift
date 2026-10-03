import SwiftUI

// MARK: - Page masthead

/// Serif page title closed with a vermilion dot, an optional tracked caption
/// beneath, and trailing actions aligned to the title's baseline.
struct PageMasthead<Trailing: View>: View {
    let title: Text
    var caption: Text?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    title
                        .font(.serif(29, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                if let caption {
                    caption
                        .font(.system(size: 11.5, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Theme.ink.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PageMasthead where Trailing == EmptyView {
    init(title: Text, caption: Text? = nil) {
        self.init(title: title, caption: caption) { EmptyView() }
    }
}

// MARK: - 最近播放

struct RecentsView: View {
    @State private var records: [PlayRecordItem] = []
    @State private var week = false
    @State private var isLoading = true

    @Environment(AccountStore.self) private var account
    @Environment(PlayerService.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageMasthead(title: Text("最近播放")) {
                    Button {
                        player.play(tracks: records.map(\.song), source: .none)
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                    }
                    .buttonStyle(.ink)
                    .disabled(records.isEmpty)
                    .opacity(records.isEmpty ? 0.45 : 1)
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 14)

                HStack(spacing: 8) {
                    Button("所有时间") { week = false }
                        .buttonStyle(.chip(isSelected: !week))
                        .accessibilityAddTraits(!week ? .isSelected : [])
                    Button("最近一周") { week = true }
                        .buttonStyle(.chip(isSelected: week))
                        .accessibilityAddTraits(week ? .isSelected : [])
                }
                .padding(.horizontal, Theme.Layout.contentInset)

                if isLoading {
                    InkLoader()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if records.isEmpty {
                    EmptyStateView(icon: "clock", title: "暂无播放记录")
                        .frame(minHeight: 300)
                } else {
                    recordList
                        .padding(.horizontal, Theme.Layout.contentInset - 10)
                }
                Color.clear.frame(height: 8)
            }
        }
        .hoverScrollIndicators()
        .navigationTitle("最近播放")
        .task(id: "\(account.sessionVersion)-\(week)") {
            await load()
        }
    }

    private var recordList: some View {
        LazyVStack(spacing: 1) {
            ForEach(Array(records.enumerated()), id: \.element.song.id) { index, record in
                TrackRow(
                    track: record.song,
                    index: index + 1,
                    style: .compact,
                    trailingText: String(localized: "\(record.playCount) 次")
                ) {
                    player.play(tracks: records.map(\.song), source: .none, startAt: record.song)
                }
            }
        }
    }

    private func load() async {
        let version = account.sessionVersion
        let requestedWeek = week
        records = []
        guard let uid = account.profile?.userId else {
            isLoading = false
            return
        }
        isLoading = records.isEmpty
        let result = try? await NeteaseAPI.playRecords(uid: uid, week: requestedWeek)
        guard !Task.isCancelled, version == account.sessionVersion, week == requestedWeek else { return }
        records = result ?? []
        isLoading = false
    }
}

// MARK: - 音乐云盘

struct CloudView: View {
    @Environment(AccountStore.self) private var account
    @State private var items: [CloudSongItem] = []
    @State private var sizeInfo: String?
    @State private var isLoading = true

    @Environment(PlayerService.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageMasthead(title: Text("音乐云盘"), caption: sizeInfo.map { Text(verbatim: $0) }) {
                    Button {
                        player.play(tracks: tracks, source: .cloud)
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                    }
                    .buttonStyle(.ink)
                    .disabled(items.isEmpty)
                    .opacity(items.isEmpty ? 0.45 : 1)
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 14)

                if isLoading {
                    InkLoader()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if items.isEmpty {
                    EmptyStateView(icon: "icloud", title: "云盘还没有歌曲",
                                   subtitle: "在网易云音乐客户端上传的歌曲会出现在这里")
                        .frame(minHeight: 300)
                } else {
                    TrackListView(tracks: tracks, style: .compact, source: .cloud)
                        .padding(.horizontal, Theme.Layout.contentInset - 10)
                }
                Color.clear.frame(height: 8)
            }
        }
        .hoverScrollIndicators()
        .navigationTitle("音乐云盘")
        .task(id: account.sessionVersion) {
            await load()
        }
    }

    private var tracks: [Track] {
        items.compactMap(\.simpleSong)
    }

    private func load() async {
        let version = account.sessionVersion
        items = []
        sizeInfo = nil
        guard account.isLoggedIn else { isLoading = false; return }
        isLoading = true
        let response = try? await NeteaseAPI.cloudSongs()
        guard !Task.isCancelled, version == account.sessionVersion else { return }
        if let response {
            items = response.data ?? []
            if let size = response.size, let max = response.maxSize, max > 0 {
                let used = String(format: "%.1f", Double(size) / 1_073_741_824)
                let total = String(format: "%.0f", Double(max) / 1_073_741_824)
                sizeInfo = String(localized: "已使用 \(used) GB / \(total) GB")
            }
        }
        isLoading = false
    }
}
