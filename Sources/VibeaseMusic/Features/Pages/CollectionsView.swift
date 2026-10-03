import SwiftUI

/// 我的收藏 — liked albums and followed artists.
struct CollectionsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case albums = "专辑"
        case artists = "歌手"

        var id: String { rawValue }
    }

    @State private var tab: Tab = .albums
    @State private var isLoading = true

    @Environment(AccountStore.self) private var account

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageMasthead(title: Text("我的收藏"))
                    .padding(.horizontal, Theme.Layout.contentInset)
                    .padding(.top, 14)

                HStack(spacing: 8) {
                    ForEach(Tab.allCases) { item in
                        Button {
                            tab = item
                        } label: {
                            Text(LocalizedStringKey(item.rawValue))
                        }
                        .buttonStyle(.chip(isSelected: tab == item))
                        .accessibilityAddTraits(tab == item ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Theme.Layout.contentInset)

                if isLoading, account.likedAlbums.isEmpty, account.likedArtists.isEmpty {
                    InkLoader()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    switch tab {
                    case .albums:
                        if account.likedAlbums.isEmpty {
                            EmptyStateView(icon: "square.stack", title: "还没有收藏专辑")
                                .frame(minHeight: 300)
                        } else {
                            CardGrid {
                                ForEach(account.likedAlbums) { album in
                                    NavigationLink(value: Destination.album(album.id)) {
                                        CoverCardBody(
                                            coverURL: album.picUrl?.resizedImageURL(384),
                                            title: album.name,
                                            subtitle: album.artistName
                                        )
                                    }
                                    .buttonStyle(.interactiveCard)
                                }
                            }
                            .padding(.horizontal, Theme.Layout.contentInset)
                        }
                    case .artists:
                        if account.likedArtists.isEmpty {
                            EmptyStateView(icon: "music.microphone", title: "还没有关注歌手")
                                .frame(minHeight: 300)
                        } else {
                            CardGrid(minWidth: 148) {
                                ForEach(account.likedArtists) { artist in
                                    NavigationLink(value: Destination.artist(artist.id)) {
                                        ArtistPortrait(url: artist.picUrl?.resizedImageURL(256),
                                                       name: artist.name, size: 128)
                                    }
                                    .buttonStyle(.interactiveCard)
                                }
                            }
                            .padding(.horizontal, Theme.Layout.contentInset)
                        }
                    }
                }
                Color.clear.frame(height: 8)
            }
        }
        .hoverScrollIndicators()
        .navigationTitle("我的收藏")
        .task(id: account.sessionVersion) {
            let version = account.sessionVersion
            isLoading = true
            guard account.isLoggedIn else { isLoading = false; return }
            await account.refreshSublists()
            guard !Task.isCancelled, version == account.sessionVersion else { return }
            isLoading = false
        }
    }
}
