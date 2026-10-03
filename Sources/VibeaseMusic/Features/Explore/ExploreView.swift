import SwiftUI

@MainActor
@Observable
final class ExploreViewModel {
    /// Shared so category selection and loaded pages survive sidebar switches.
    static let shared = ExploreViewModel()

    static let categories: [String] = [
        "全部", "推荐歌单", "精品歌单", "排行榜", "官方",
        "华语", "流行", "摇滚", "民谣", "电子", "轻音乐", "说唱", "爵士", "古典",
        "影视原声", "ACG", "古风", "怀旧", "治愈", "放松", "伤感", "快乐",
        "学习", "工作", "运动", "驾车", "夜晚",
    ]

    var selectedCategory = "全部"
    var playlists: [PlaylistSummary] = []
    var toplists: [ToplistItem] = []
    var isLoading = false
    var hasMore = true
    private var offset = 0
    private var highQualityBefore = 0
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    func select(_ category: String) {
        guard category != selectedCategory || playlists.isEmpty else { return }
        selectedCategory = category
        playlists = []
        toplists = []
        offset = 0
        highQualityBefore = 0
        hasMore = true
        isLoading = false
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        loadTask = Task { await loadMore(generation: generation, category: category) }
    }

    func loadMore() async {
        await loadMore(generation: loadGeneration, category: selectedCategory)
    }

    private func loadMore(generation: Int, category: String) async {
        guard !isLoading, hasMore else { return }
        guard generation == loadGeneration, category == selectedCategory else { return }
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        // A cancelled `.task` (leaving the page mid-load) must not mark the shared
        // model as exhausted, or the page stays blank on return.
        func isCurrent() -> Bool {
            !Task.isCancelled && generation == loadGeneration && category == selectedCategory
        }

        switch category {
        case "排行榜":
            let lists = try? await NeteaseAPI.toplists()
            guard isCurrent() else { return }
            if let lists { toplists = lists }
            hasMore = false
        case "推荐歌单":
            let result = try? await NeteaseAPI.personalizedPlaylists(limit: 100)
            guard isCurrent() else { return }
            if let result { playlists = result }
            hasMore = false
        case "精品歌单":
            let result = try? await NeteaseAPI.highQualityPlaylists(before: highQualityBefore)
            guard isCurrent() else { return }
            if let result {
                let existing = Set(playlists.map(\.id))
                playlists += result.playlists.filter { !existing.contains($0.id) }
                highQualityBefore = result.lasttime ?? 0
                hasMore = result.more ?? false
            } else {
                hasMore = false
            }
        default:
            let cat = category == "官方" ? "官方" : category
            let result = try? await NeteaseAPI.topPlaylists(
                category: cat == "全部" ? "全部" : cat, offset: offset
            )
            guard isCurrent() else { return }
            if let result {
                let existing = Set(playlists.map(\.id))
                playlists += result.playlists.filter { !existing.contains($0.id) }
                offset += 50
                hasMore = (result.more ?? false) && offset < 500
            } else {
                hasMore = false
            }
        }
    }
}

private struct CategoryScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0
}

struct ExploreView: View {
    @State private var model = ExploreViewModel.shared
    @State private var categoryMetrics = CategoryScrollMetrics()
    @State private var isCategoryTrackHovered = false
    @State private var isCategoryScrolling = false
    @State private var categoryHideTask: Task<Void, Never>?
    @State private var categoryPosition = ScrollPosition()
    @State private var categoryDragStartOffset: CGFloat?
    @State private var categoryResizeQuietUntil = Date.distantPast
    @Environment(PlayerService.self) private var player

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                PageMasthead(title: Text("精选"))
                    .padding(.horizontal, Theme.Layout.contentInset)
                    .padding(.top, 14)

                categoryChips

                if model.selectedCategory == "排行榜" {
                    ToplistGrid(toplists: model.toplists)
                        .padding(.horizontal, Theme.Layout.contentInset)
                } else {
                    CardGrid {
                        ForEach(model.playlists) { playlist in
                            NavigationCoverCard(
                                destination: .playlist(playlist.id),
                                coverURL: playlist.coverURL?.resizedImageURL(384),
                                title: playlist.name,
                                playCount: playlist.playCount,
                                onPlay: { playPlaylist(playlist.id) }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Layout.contentInset)

                    if model.isLoading {
                        HStack {
                            Spacer()
                            InkLoader(size: model.playlists.isEmpty ? 34 : 22)
                            Spacer()
                        }
                        .frame(minHeight: model.playlists.isEmpty ? 260 : 0)
                        .padding(.vertical, 20)
                    } else if model.hasMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await model.loadMore() }
                            }
                    }
                }

                Color.clear.frame(height: 12)
            }
        }
        .thinAutoScrollIndicators(.vertical)
        .navigationTitle("精选")
        .task {
            if model.playlists.isEmpty, model.toplists.isEmpty {
                await model.loadMore()
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Spacer().frame(width: Theme.Layout.contentInset - 8)
                ForEach(ExploreViewModel.categories, id: \.self) { category in
                    Button {
                        model.select(category)
                    } label: {
                        Text(LocalizedStringKey(category))
                    }
                    .buttonStyle(.chip(isSelected: model.selectedCategory == category))
                }
                Spacer().frame(width: Theme.Layout.contentInset - 8)
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 10)
        .scrollPosition($categoryPosition)
        .onScrollGeometryChange(for: CategoryScrollMetrics.self) { geometry in
            CategoryScrollMetrics(offset: geometry.contentOffset.x,
                                  contentWidth: geometry.contentSize.width,
                                  viewportWidth: geometry.containerSize.width)
        } action: { old, new in
            categoryMetrics = new
            if abs(old.viewportWidth - new.viewportWidth) >= 0.5 {
                categoryResizeQuietUntil = Date().addingTimeInterval(0.6)
                categoryHideTask?.cancel()
                isCategoryScrolling = false
                return
            }
            guard old.contentWidth > 0,
                  Date() >= categoryResizeQuietUntil,
                  abs(old.offset - new.offset) > 0.5 else { return }
            isCategoryScrolling = true
            categoryHideTask?.cancel()
            categoryHideTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                if !Task.isCancelled { isCategoryScrolling = false }
            }
        }
        .overlay(alignment: .bottom) { categoryScrollIndicator }
    }

    private var categoryScrollIndicator: some View {
        GeometryReader { geometry in
            let travel = max(categoryMetrics.contentWidth - categoryMetrics.viewportWidth, 0)
            let thumbWidth = max(28, geometry.size.width * categoryMetrics.viewportWidth
                                 / max(categoryMetrics.contentWidth, 1))
            let thumbTravel = max(geometry.size.width - thumbWidth, 0)
            let fraction = travel > 0 ? min(max(categoryMetrics.offset / travel, 0), 1) : 0
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.001))
                Capsule()
                .fill(Theme.ink.opacity(0.3))
                .frame(width: thumbWidth, height: 3)
                .offset(x: thumbTravel * fraction)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .opacity(travel > 0 && (isCategoryTrackHovered || isCategoryScrolling) ? 1 : 0)
            }
                .contentShape(Rectangle())
                .onHover { isCategoryTrackHovered = $0 }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard thumbTravel > 0 else { return }
                        if categoryDragStartOffset == nil {
                            categoryDragStartOffset = categoryMetrics.offset
                        }
                        let next = min(max((categoryDragStartOffset ?? 0)
                                           + value.translation.width * travel / thumbTravel, 0), travel)
                        categoryPosition.scrollTo(x: next)
                    }
                    .onEnded { _ in categoryDragStartOffset = nil })
        }
        .frame(height: 10)
    }

    private func playPlaylist(_ id: Int) {
        Task {
            guard let detail = try? await NeteaseAPI.playlistDetail(id: id) else { return }
            var tracks = detail.playlist.tracks
            if tracks.isEmpty {
                let ids = detail.playlist.trackIds.map(\.id)
                tracks = (try? await NeteaseAPI.songDetails(ids: Array(ids.prefix(500))))?.songs ?? []
            }
            player.play(tracks: tracks, source: .playlist(id))
        }
    }
}

// MARK: - Toplist grid

struct ToplistGrid: View {
    let toplists: [ToplistItem]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 20)],
            alignment: .leading, spacing: 20
        ) {
            ForEach(toplists) { toplist in
                ToplistGridItem(toplist: toplist)
            }
        }
    }
}

private struct ToplistGridItem: View {
    let toplist: ToplistItem

    @State private var isHovering = false

    var body: some View {
        NavigationLink(value: Destination.playlist(toplist.id)) {
            HStack(spacing: 16) {
                CoverArtwork(url: toplist.coverImgUrl?.resizedImageURL(256), size: 104, lifted: isHovering)
                VStack(alignment: .leading, spacing: 6) {
                    Text(toplist.name)
                        .font(.serif(15.5, .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(toplist.updateFrequency ?? "")
                        .font(.system(size: 10.5))
                        .tracking(1)
                        .foregroundStyle(Theme.ink.opacity(0.45))
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 0.75)
                        .padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(toplist.tracks.prefix(3).enumerated()), id: \.offset) { i, preview in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Text(verbatim: "\(i + 1)")
                                    .font(.serif(12, .bold))
                                    .foregroundStyle(i == 0 ? Theme.accent : Theme.ink.opacity(0.4))
                                    .frame(width: 10, alignment: .leading)
                                Text(verbatim: "\(preview.first) - \(preview.second)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.ink.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .paperSheet(cornerRadius: Theme.Radius.large, lifted: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.interactiveCard)
        .onHover { isHovering = $0 }
    }
}

struct ToplistsView: View {
    @State private var toplists: [ToplistItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageMasthead(title: Text("排行榜"))
                ToplistGrid(toplists: toplists)
            }
            .padding(.horizontal, Theme.Layout.contentInset)
            .padding(.top, 14)
            .padding(.bottom, Theme.Layout.contentInset)
        }
        .hoverScrollIndicators()
        .navigationTitle("排行榜")
        .task {
            if toplists.isEmpty {
                toplists = (try? await NeteaseAPI.toplists()) ?? []
            }
        }
    }
}
