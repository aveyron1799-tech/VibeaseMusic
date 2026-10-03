// Classic theme: the original interface, kept intact alongside Washi.
import AppKit
import SwiftUI

// MARK: - Cover card (playlists / albums)

struct ClassicCoverCard: View {
    let coverURL: URL?
    let title: String
    var subtitle: String?
    var playCount: Int = 0
    var size: CGFloat = ClassicTheme.Layout.cardSize
    var onPlay: (() -> Void)?
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: coverURL)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ClassicTheme.Radius.standard, style: .continuous)
                                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    if playCount > 0 {
                        ClassicPlayCountBadge(count: playCount)
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                    if let onPlay {
                        ClassicPlayOverlayButton(visible: isHovering, action: onPlay)
                            .padding(8)
                    }
                }
                .frame(width: size, height: size)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.classicInteractiveCard)
        .onHover { isHovering = $0 }
    }
}

/// A navigable card with its play button outside the NavigationLink hit region.
/// Keeping the two controls as siblings prevents a play click from also routing.
struct ClassicNavigationCoverCard: View {
    let destination: Destination
    let coverURL: URL?
    let title: String
    var subtitle: String?
    var playCount: Int = 0
    var onPlay: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationLink(value: destination) {
                ClassicCoverCardBody(
                    coverURL: coverURL,
                    title: title,
                    subtitle: subtitle,
                    playCount: playCount
                )
            }
            .buttonStyle(.classicInteractiveCard)

            if let onPlay {
                ClassicPlayOverlayButton(visible: isHovering, action: onPlay)
                    .padding(8)
                    .frame(width: ClassicTheme.Layout.cardSize, height: ClassicTheme.Layout.cardSize, alignment: .bottomLeading)
                    .zIndex(1)
            }
        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Artist card (circular)

struct ClassicArtistCard: View {
    let artist: ArtistSummary
    var size: CGFloat = 128
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 10) {
                CachedAsyncImage(url: artist.picUrl?.resizedImageURL(256))
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
                Text(artist.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .frame(width: size + 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.classicInteractiveCard)
    }
}

// MARK: - Horizontal shelf

/// A horizontal scroll section whose track reaches the column edges;
/// the resting inset lives inside the HStack (kaset's slide-under trick).
struct ClassicShelf<Content: View>: View {
    let title: LocalizedStringKey
    var destination: Destination?
    var seeAll: (() -> Void)?
    var spacing: CGFloat = 16
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false
    @State private var pageRequest = 0

    private var contentHeight: CGFloat { ClassicTheme.Layout.cardSize + 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ClassicSectionHeader(title: title, destination: destination, action: seeAll)
                if let destination {
                    Spacer()
                    NavigationLink(value: destination) {
                        HStack(spacing: 3) {
                            Text("全部")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ClassicTheme.Layout.contentInset)

            ShelfScrollView(contentHeight: contentHeight, pageRequest: pageRequest) {
                HStack(alignment: .top, spacing: spacing) {
                    Spacer().frame(width: ClassicTheme.Layout.contentInset - spacing)
                    content()
                    Spacer().frame(width: ClassicTheme.Layout.contentInset - spacing)
                }
            }
            .frame(height: contentHeight)
            .overlay(alignment: .leading) { pagerButton(direction: -1) }
            .overlay(alignment: .trailing) { pagerButton(direction: 1) }
            .onHover { isHovering = $0 }
        }
    }

    private func pagerButton(direction: Int) -> some View {
        Button {
            pageRequest += direction
        } label: {
            Text(direction < 0 ? "←" : "→")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .classicCompatGlass(interactive: true, in: Circle())
                .overlay(Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .animation(ClassicAnimation.quick, value: isHovering)
        .padding(.horizontal, 6)
    }
}

// MARK: - AppKit horizontal shelf scroll view


// MARK: - Adaptive card grid

struct ClassicCardGrid<Content: View>: View {
    var minWidth: CGFloat = ClassicTheme.Layout.cardSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minWidth, maximum: minWidth + 40),
                               spacing: 20, alignment: .top)],
            alignment: .leading, spacing: 24
        ) {
            content()
        }
    }
}

// MARK: - Error / empty states

struct ClassicErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("加载失败", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(ClassicTheme.accent)
        }
    }
}

struct ClassicEmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
