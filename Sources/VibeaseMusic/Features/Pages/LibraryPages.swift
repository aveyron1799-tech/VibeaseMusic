import SwiftUI

// MARK: - 最近播放

struct RecentsView: View {
    @State private var records: [PlayRecordItem] = []
    @State private var week = false
    @State private var isLoading = true

    @Environment(AccountStore.self) private var account
    @Environment(PlayerService.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Picker("", selection: $week) {
                        Text("所有时间").tag(false)
                        Text("最近一周").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)

                    Spacer()

                    Button {
                        player.play(tracks: records.map(\.song), source: .none)
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.accentGradient, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .disabled(records.isEmpty)
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 12)

                if isLoading {
                    ProgressView()
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let sizeInfo {
                        Text(sizeInfo)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        player.play(tracks: tracks, source: .cloud)
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.accentGradient, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .disabled(items.isEmpty)
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 12)

                if isLoading {
                    ProgressView()
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
