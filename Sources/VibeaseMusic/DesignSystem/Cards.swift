import AppKit
import SwiftUI

// MARK: - Cover card (playlists / albums)

/// Artwork mounted like a print: thin ink edge, resting flat on the paper,
/// casting a soft warm shadow once lifted.
struct CoverArtwork: View {
    let url: URL?
    var size: CGFloat = Theme.Layout.cardSize
    var lifted = false
    var cornerRadius: CGFloat = Theme.Radius.standard

    var body: some View {
        CachedAsyncImage(url: url)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.75)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.sheet)
                    .shadow(color: Theme.shadow.opacity(lifted ? 1.1 : 0.45),
                            radius: lifted ? 14 : 3, y: lifted ? 9 : 1.5)
            )
            .animation(AppAnimation.spring, value: lifted)
    }
}

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
            CoverCardBody(coverURL: coverURL, title: title, subtitle: subtitle,
                          playCount: playCount, size: size, lifted: isHovering)
        }
        .buttonStyle(.interactiveCard)
        .overlay(alignment: .topLeading) {
            if let onPlay {
                PlayOverlayButton(visible: isHovering, action: onPlay)
                    .padding(10)
                    .frame(width: size, height: size, alignment: .bottomTrailing)
                    .offset(y: isHovering ? -3 : 0)
            }
        }
        .onHover { isHovering = $0 }
    }
}

/// Card body without its own Button wrapper (for use inside NavigationLink).
struct CoverCardBody: View {
    let coverURL: URL?
    let title: String
    var subtitle: String?
    var playCount: Int = 0
    var size: CGFloat = Theme.Layout.cardSize
    var lifted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                CoverArtwork(url: coverURL, size: size, lifted: lifted)
                if playCount > 0 {
                    PlayCountBadge(count: playCount)
                        .padding(7)
                }
            }
            .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Theme.ink.opacity(0.92))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: size, alignment: .leading)
        }
        .frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
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
                    playCount: playCount,
                    lifted: isHovering
                )
            }
            .buttonStyle(.interactiveCard)

            if let onPlay {
                PlayOverlayButton(visible: isHovering, action: onPlay)
                    .padding(10)
                    .frame(width: Theme.Layout.cardSize, height: Theme.Layout.cardSize, alignment: .bottomTrailing)
                    .offset(y: isHovering ? -3 : 0)
                    .animation(AppAnimation.spring, value: isHovering)
                    .zIndex(1)
            }
        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Artist card (circular)

struct ArtistCard: View {
    let artist: ArtistSummary
    var size: CGFloat = 124
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ArtistPortrait(url: artist.picUrl?.resizedImageURL(256), name: artist.name, size: size)
        }
        .buttonStyle(.interactiveCard)
    }
}

/// Round portrait with an ensō that is brushed around it on hover.
struct ArtistPortrait: View {
    let url: URL?
    let name: String
    var size: CGFloat = 124

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 12) {
            CachedAsyncImage(url: url)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
                .shadow(color: Theme.shadow.opacity(isHovering ? 0.9 : 0.3), radius: isHovering ? 12 : 3,
                        y: isHovering ? 7 : 1)
                .overlay {
                    Enso(progress: isHovering ? 1 : 0, lineWidth: 3.2, color: Theme.ink.opacity(0.85))
                        .frame(width: size + 18, height: size + 18)
                        .animation(isHovering ? .easeOut(duration: 0.7) : .easeIn(duration: 0.2), value: isHovering)
                }
            Text(name)
                .font(.serif(14, .medium))
                .lineLimit(1)
                .foregroundStyle(Theme.ink)
        }
        .frame(width: size + 20)
        .padding(.top, 9)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

// MARK: - Horizontal shelf

/// A horizontal scroll section whose track reaches the column edges;
/// the resting inset lives inside the HStack (kaset's slide-under trick).
struct Shelf<Content: View>: View {
    let title: LocalizedStringKey
    var destination: Destination?
    var seeAll: (() -> Void)?
    var spacing: CGFloat = 22
    @ViewBuilder var content: () -> Content

    @State private var isHovering = false
    @State private var pageRequest = 0

    private var contentHeight: CGFloat { Theme.Layout.cardSize + 86 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: title, destination: destination, action: seeAll)
                if let destination {
                    Spacer()
                    NavigationLink(value: destination) {
                        HStack(spacing: 4) {
                            Text("全部")
                                .font(.system(size: 11.5))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundStyle(Theme.ink.opacity(0.5))
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
                // Room for cards to lift without their shadow being clipped.
                .padding(.top, 8)
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
            Image(systemName: direction < 0 ? "arrow.left" : "arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .compatGlass(interactive: true, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0)
        .offset(x: isHovering ? 0 : CGFloat(direction) * 8)
        .allowsHitTesting(isHovering)
        .animation(AppAnimation.spring, value: isHovering)
        .padding(.horizontal, 8)
        .padding(.bottom, 64)
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
                               spacing: 22, alignment: .top)],
            alignment: .leading, spacing: 30
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
        VStack(spacing: 18) {
            Enso(progress: 0.72, lineWidth: 5, color: Theme.ink.opacity(0.55))
                .frame(width: 70, height: 70)
            VStack(spacing: 6) {
                Text("加载失败")
                    .font(.serif(18, .bold))
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("重试", action: retry)
                .buttonStyle(.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Enso(lineWidth: 4.5, color: Theme.ink.opacity(0.35))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
            Text(title)
                .font(.serif(17, .bold))
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
