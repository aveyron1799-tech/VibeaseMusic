import SwiftUI

// MARK: - Skeletons

/// Placeholder: a pale ink wash drifting across the paper.
struct SkeletonView: View {
    var cornerRadius: CGFloat = Theme.Radius.standard

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.2) / 2.2
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.wash)
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Theme.ink.opacity(0.05), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.7)
                        .offset(x: (geo.size.width * 1.7) * phase - geo.size.width * 0.7)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct SkeletonCardView: View {
    var size: CGFloat = Theme.Layout.cardSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonView().frame(width: size, height: size)
            SkeletonView(cornerRadius: 3).frame(width: size * 0.8, height: 11)
            SkeletonView(cornerRadius: 3).frame(width: size * 0.5, height: 9)
        }
    }
}

struct SkeletonShelf: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SkeletonView(cornerRadius: 3).frame(width: 110, height: 18)
            HStack(spacing: 22) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonCardView()
                }
            }
        }
    }
}

// MARK: - Staggered entrance

private enum AnimationCache {
    nonisolated(unsafe) static var animated = Set<String>()

    static func hasAnimated(_ key: String) -> Bool { animated.contains(key) }

    static func markAnimated(_ key: String) {
        if animated.count > 600 { animated.removeAll() }
        animated.insert(key)
    }
}

struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int
    var itemID: String

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .blur(radius: isVisible ? 0 : 3)
            .onAppear {
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    || AnimationCache.hasAnimated(itemID) {
                    isVisible = true
                    return
                }
                withAnimation(.easeOut(duration: 0.55).delay(AppAnimation.stagger(for: index))) {
                    isVisible = true
                }
                AnimationCache.markAnimated(itemID)
            }
    }
}

extension View {
    func staggeredAppearance(index: Int, id: String) -> some View {
        modifier(StaggeredAppearanceModifier(index: index, itemID: id))
    }
}

// MARK: - Section header

/// Serif title closed by a small vermilion full stop. Linked headers paint a
/// brush underline on hover.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: String?
    var destination: Destination?
    var action: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let destination {
                NavigationLink(value: destination) {
                    headerTitleContent(linked: true)
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            } else if let action {
                Button(action: action) {
                    headerTitleContent(linked: true)
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            } else {
                headerTitleContent(linked: false)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func headerTitleContent(linked: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(title)
                .font(.serif(21, .bold))
                .foregroundStyle(Theme.ink)
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .offset(y: -1)
                .scaleEffect(isHovering ? 1.35 : 1)
            if linked {
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink.opacity(0.5))
                    .padding(.leading, 6)
                    .opacity(isHovering ? 1 : 0)
                    .offset(x: isHovering ? 0 : -6)
            }
        }
        .background(alignment: .bottomLeading) {
            if linked {
                PaintedBrush(painted: isHovering, color: Theme.accent.opacity(0.22))
                    .frame(height: 7)
                    .offset(y: 2)
            }
        }
        .animation(AppAnimation.spring, value: isHovering)
    }
}

// MARK: - Badges

struct PlayCountBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 7, weight: .bold))
            Text(Formatters.playCount(count))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(Color(red: 0.98, green: 0.96, blue: 0.92))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(red: 0.1, green: 0.09, blue: 0.08).opacity(0.42), in: Capsule())
    }
}

/// VIP: gold leaf outline, like a gilt mark on a book spine.
struct VIPBadge: View {
    var body: some View {
        Text("VIP")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Theme.gold.opacity(0.8), lineWidth: 0.8)
            )
    }
}

struct QualityTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Theme.accent.opacity(0.65), lineWidth: 0.8)
            )
    }
}

// MARK: - Hover play overlay

/// The play control on covers is a seal: it rotates into place as if being
/// pressed onto the artwork, and blooms ink when clicked.
struct PlayOverlayButton: View {
    var visible: Bool
    var size: CGFloat = 38
    let action: () -> Void

    @State private var presses = 0

    var body: some View {
        Button {
            presses += 1
            action()
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Color(red: 0.99, green: 0.96, blue: 0.92))
                .offset(x: 1)
                .frame(width: size, height: size)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
                .shadow(color: Theme.accentDeep.opacity(0.35), radius: 6, y: 3)
                .inkBloom(trigger: presses, color: Theme.accent, scale: 2)
        }
        .buttonStyle(.pressable)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
        .rotationEffect(.degrees(visible ? 0 : -14))
        .scaleEffect(visible ? 1 : 0.6)
        .animation(AppAnimation.bouncy, value: visible)
    }
}

// MARK: - Marquee

/// Scrolls text horizontally when it overflows, with faded edges.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .medium)

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var needsMarquee: Bool { textWidth > containerWidth + 1 }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 32) {
                marqueeLabel
                if needsMarquee {
                    marqueeLabel
                }
            }
            .offset(x: offset)
            .frame(maxHeight: .infinity, alignment: .leading)
            .onAppear { containerWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, newValue in containerWidth = newValue }
        }
        .clipped()
        .mask(edgeFadeMask)
        .onChange(of: text) {
            restart()
        }
        .onChange(of: needsMarquee) {
            restart()
        }
        .background(
            Text(text)
                .font(font)
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { textWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, newValue in textWidth = newValue }
                    }
                )
        )
    }

    private var marqueeLabel: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: animating ? .clear : .black, location: 0),
                .init(color: .black, location: animating ? 0.06 : 0),
                .init(color: .black, location: needsMarquee ? 0.94 : 1),
                .init(color: needsMarquee ? .clear : .black, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private func restart() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            offset = 0
            animating = false
        }
        guard needsMarquee, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let distance = textWidth + 32
        let duration = Double(distance) / 24
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard needsMarquee else { return }
            animating = true
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = -distance
            }
        }
    }
}
