// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI


private struct ClassicCategoryScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0
}

struct ClassicExploreView: View {
    @State private var model = ExploreViewModel.shared
    @State private var categoryMetrics = ClassicCategoryScrollMetrics()
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
                categoryChips
                    .padding(.top, 8)

                if model.selectedCategory == "排行榜" {
                    ClassicToplistGrid(toplists: model.toplists)
                        .padding(.horizontal, ClassicTheme.Layout.contentInset)
                } else {
                        ClassicCardGrid {
                            ForEach(model.playlists) { playlist in
                            ClassicNavigationCoverCard(
                                destination: .playlist(playlist.id),
                                coverURL: playlist.coverURL?.resizedImageURL(384),
                                title: playlist.name,
                                playCount: playlist.playCount,
                                onPlay: { playPlaylist(playlist.id) }
                            )
                        }
                    }
                    .padding(.horizontal, ClassicTheme.Layout.contentInset)

                    if model.isLoading {
                        HStack {
                            Spacer()
                            ProgressView().controlSize(.small)
                            Spacer()
                        }
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
                Spacer().frame(width: ClassicTheme.Layout.contentInset - 8)
                ForEach(ExploreViewModel.categories, id: \.self) { category in
                    Button {
                        model.select(category)
                    } label: {
                        Text(LocalizedStringKey(category))
                    }
                    .buttonStyle(.classicChip(isSelected: model.selectedCategory == category))
                }
                Spacer().frame(width: ClassicTheme.Layout.contentInset - 8)
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, 10)
        .scrollPosition($categoryPosition)
        .onScrollGeometryChange(for: ClassicCategoryScrollMetrics.self) { geometry in
            ClassicCategoryScrollMetrics(offset: geometry.contentOffset.x,
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
                .fill(.secondary.opacity(0.7))
                .frame(width: thumbWidth, height: 5)
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
            if tracks.count < detail.playlist.trackCount {
                let ids = detail.playlist.trackIds.map(\.id)
                if let full = try? await NeteaseAPI.songDetails(ids: Array(ids.prefix(1000))),
                   !full.songs.isEmpty {
                    tracks = full.songs
                }
            }
            player.play(tracks: tracks, source: .playlist(id))
        }
    }
}

// MARK: - Toplist grid

struct ClassicToplistGrid: View {
    let toplists: [ToplistItem]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 20)],
            alignment: .leading, spacing: 20
        ) {
            ForEach(toplists) { toplist in
                NavigationLink(value: Destination.playlist(toplist.id)) {
                    HStack(spacing: 14) {
                        CachedAsyncImage(url: toplist.coverImgUrl?.resizedImageURL(256))
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(toplist.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(toplist.updateFrequency ?? "")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.tertiary)
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(toplist.tracks.prefix(3).enumerated()), id: \.offset) { i, preview in
                                    Text("\(i + 1). \(preview.first) - \(preview.second)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: ClassicTheme.Radius.large, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.classicInteractiveCard)
            }
        }
    }
}

struct ClassicToplistsView: View {
    @State private var toplists: [ToplistItem] = []

    var body: some View {
        ScrollView {
            ClassicToplistGrid(toplists: toplists)
                .padding(ClassicTheme.Layout.contentInset)
        }
        .classicHoverScrollIndicators()
        .navigationTitle("排行榜")
        .task {
            if toplists.isEmpty {
                toplists = (try? await NeteaseAPI.toplists()) ?? []
            }
        }
    }
}
