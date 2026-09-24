import AppKit
import SwiftUI

// MARK: - Cover card (playlists / albums)

struct CoverCard: View {
    let coverURL: URL?
    let title: String
    var subtitle: String?
    var playCount: Int = 0
    var size: CGFloat = Theme.Layout.cardSize
    var onPlay: (() -> Void)?
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: coverURL)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.standard, style: .continuous)
                                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    if playCount > 0 {
                        PlayCountBadge(count: playCount)
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                    if let onPlay {
                        PlayOverlayButton(visible: isHovering, action: onPlay)
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
        .buttonStyle(.interactiveCard)
        .onHover { isHovering = $0 }
    }
}

/// A navigable card with its play button outside the NavigationLink hit region.
/// Keeping the two controls as siblings prevents a play click from also routing.
struct NavigationCoverCard: View {
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
                CoverCardBody(
                    coverURL: coverURL,
                    title: title,
                    subtitle: subtitle,
                    playCount: playCount
                )
            }
            .buttonStyle(.interactiveCard)

            if let onPlay {
                PlayOverlayButton(visible: isHovering, action: onPlay)
                    .padding(8)
                    .frame(width: Theme.Layout.cardSize, height: Theme.Layout.cardSize, alignment: .bottomLeading)
                    .zIndex(1)
            }
        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Artist card (circular)

struct ArtistCard: View {
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
        .buttonStyle(.interactiveCard)
    }
}

// MARK: - Horizontal shelf

/// A horizontal scroll section whose track reaches the column edges;
/// the resting inset lives inside the HStack (kaset's slide-under trick).
struct Shelf<Content: View>: View {
    let title: LocalizedStringKey
    var destination: Destination?
    var seeAll: (() -> Void)?
    var spacing: CGFloat = 16
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false
    @State private var pageRequest = 0

    private var contentHeight: CGFloat { Theme.Layout.cardSize + 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: title, destination: destination, action: seeAll)
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
            .padding(.horizontal, Theme.Layout.contentInset)

            ShelfScrollView(contentHeight: contentHeight, pageRequest: pageRequest) {
                HStack(alignment: .top, spacing: spacing) {
                    Spacer().frame(width: Theme.Layout.contentInset - spacing)
                    content()
                    Spacer().frame(width: Theme.Layout.contentInset - spacing)
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
                .compatGlass(interactive: true, in: Circle())
                .overlay(Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .animation(AppAnimation.quick, value: isHovering)
        .padding(.horizontal, 6)
    }
}

// MARK: - AppKit horizontal shelf scroll view

/// A horizontal shelf that consumes vertical wheel events so they cannot leak
/// into the page scroll view when the shelf reaches either edge.
struct ShelfScrollView<Content: View>: NSViewRepresentable {
    let contentHeight: CGFloat
    var pageRequest: Int = 0
    let content: Content

    init(contentHeight: CGFloat, pageRequest: Int = 0, @ViewBuilder content: () -> Content) {
        self.contentHeight = contentHeight
        self.pageRequest = pageRequest
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var handledPageRequest = 0
    }

    func makeNSView(context: Context) -> ShelfNSScrollView {
        let view = ShelfNSScrollView(contentHeight: contentHeight)
        view.setContent(AnyView(content.frame(minHeight: contentHeight, alignment: .top)))
        return view
    }

    func updateNSView(_ nsView: ShelfNSScrollView, context: Context) {
        nsView.contentHeight = contentHeight
        nsView.setContent(AnyView(content.frame(minHeight: contentHeight, alignment: .top)))

        let delta = pageRequest - context.coordinator.handledPageRequest
        context.coordinator.handledPageRequest = pageRequest
        if delta != 0 {
            nsView.scrollByPage(direction: delta > 0 ? 1 : -1)
        }
    }
}

final class ShelfNSScrollView: NSScrollView {
    var contentHeight: CGFloat

    private var hostingView: NSHostingView<AnyView>?

    init(contentHeight: CGFloat) {
        self.contentHeight = contentHeight
        super.init(frame: .zero)

        drawsBackground = false
        backgroundColor = .clear
        hasVerticalScroller = false
        hasHorizontalScroller = false
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(_ content: AnyView) {
        if let hostingView {
            hostingView.rootView = content
        } else {
            let hostingView = NSHostingView(rootView: content)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.hostingView = hostingView
            documentView = hostingView
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        updateDocumentSize()
    }

    var horizontalOffset: CGFloat {
        contentView.bounds.origin.x
    }

    var maxHorizontalOffset: CGFloat {
        max(0, (documentView?.frame.width ?? 0) - contentView.bounds.width)
    }

    func setHorizontalOffset(_ value: CGFloat) {
        let target = min(max(value, 0), maxHorizontalOffset)
        var origin = contentView.bounds.origin
        origin.x = target
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }

    func scrollByPage(direction: Int) {
        guard direction != 0, maxHorizontalOffset > 0 else { return }
        let page = max(contentView.bounds.width * 0.85, 240)
        let target = min(max(horizontalOffset + CGFloat(direction) * page, 0),
                         maxHorizontalOffset)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            contentView.animator().setBoundsOrigin(
                NSPoint(x: target, y: contentView.bounds.origin.y)
            )
        }
    }

    private func updateDocumentSize() {
        guard let hostingView else { return }
        let fittingSize = hostingView.fittingSize
        let width = max(contentView.bounds.width, fittingSize.width)
        let height = max(contentHeight, contentView.bounds.height)
        let frame = NSRect(x: 0, y: 0, width: width, height: height)
        if hostingView.frame != frame {
            hostingView.frame = frame
        }
    }
}

// MARK: - Adaptive card grid

struct CardGrid<Content: View>: View {
    var minWidth: CGFloat = Theme.Layout.cardSize
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

struct ErrorStateView: View {
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
                .tint(Theme.accent)
        }
    }
}

struct EmptyStateView: View {
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
