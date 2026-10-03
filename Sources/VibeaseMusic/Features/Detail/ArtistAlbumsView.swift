import SwiftUI

struct ArtistAlbumsView: View {
    let artistID: Int
    let artistName: String

    enum AlbumFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case albums = "专辑"
        case eps = "EP 与单曲"

        var id: String { rawValue }
    }

    @State private var filter: AlbumFilter = .all
    @State private var allAlbums: [AlbumSummary] = []
    @State private var offset = 0
    @State private var hasMore = true
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    private var filteredAlbums: [AlbumSummary] {
        switch filter {
        case .all:
            return allAlbums
        case .albums:
            return allAlbums.filter { $0.size > 1 }
        case .eps:
            return allAlbums.filter { $0.size <= 1 }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: artistName)
                        Text("全部专辑")
                            .font(.serif(29, .bold))
                            .foregroundStyle(Theme.ink)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(AlbumFilter.allCases) { item in
                            Button(LocalizedStringKey(item.rawValue)) { filter = item }
                                .buttonStyle(.chip(isSelected: filter == item))
                        }
                    }
                }
                .padding(.horizontal, Theme.Layout.contentInset)
                .padding(.top, 22)

                if isLoading && allAlbums.isEmpty {
                    InkLoader(size: 36, color: Theme.ink.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let errorMessage, allAlbums.isEmpty {
                    ErrorStateView(message: errorMessage) {
                        Task { await loadInitial() }
                    }
                    .frame(minHeight: 300)
                } else if filteredAlbums.isEmpty {
                    EmptyStateView(
                        icon: "square.stack",
                        title: "暂无此类专辑",
                        subtitle: "没有找到符合筛选条件的专辑作品"
                    )
                    .frame(minHeight: 260)
                    loadMoreRow
                } else {
                    CardGrid {
                        ForEach(filteredAlbums) { album in
                            NavigationLink(value: Destination.album(album.id)) {
                                CoverCardBody(
                                    coverURL: album.picUrl?.resizedImageURL(384),
                                    title: album.name,
                                    subtitle: album.publishYear
                                )
                            }
                            .buttonStyle(.interactiveCard)
                        }
                    }
                    .padding(.horizontal, Theme.Layout.contentInset)

                    loadMoreRow
                }

                Color.clear.frame(height: 16)
            }
        }
        .hoverScrollIndicators()
        .navigationTitle("\(artistName) 的专辑")
        .task(id: artistID) {
            await loadInitial()
        }
    }

    /// Also shown under the empty state: the filtered kind may only exist on later pages.
    @ViewBuilder
    private var loadMoreRow: some View {
        if hasMore {
            HStack {
                Spacer()
                if isLoadingMore {
                    InkLoader(size: 24, color: Theme.ink.opacity(0.5))
                } else {
                    Button("加载更多专辑") {
                        Task { await loadMore() }
                    }
                    .buttonStyle(.inkOutline)
                }
                Spacer()
            }
            .padding(.vertical, 24)
        }
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        offset = 0
        do {
            let res = try await NeteaseAPI.artistAlbums(id: artistID, limit: 60, offset: 0)
            allAlbums = res.hotAlbums
            hasMore = res.more ?? (res.hotAlbums.count >= 60)
            offset = res.hotAlbums.count
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        do {
            let res = try await NeteaseAPI.artistAlbums(id: artistID, limit: 60, offset: offset)
            allAlbums.append(contentsOf: res.hotAlbums)
            hasMore = res.more ?? (res.hotAlbums.count >= 60)
            offset += res.hotAlbums.count
            isLoadingMore = false
        } catch {
            isLoadingMore = false
        }
    }
}
