import AppKit
import SwiftUI

/// Keep AppKit's scroll interaction and automatic fade while drawing a
/// constant-width vertical knob, even when AppKit expands its hover target.
private final class ThinOverlayScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { self == ThinOverlayScroller.self }

    private var pointerOnTrack = false
    private var isScrolling = false
    private var trackingArea: NSTrackingArea?
    private var scrollObserver: NSObjectProtocol?
    private var hideWork: DispatchWorkItem?
    private var lastOrigin: NSPoint = .zero

    deinit {
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
        hideWork?.cancel()
    }

    func observeScrolling(in scrollView: NSScrollView) {
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
        let clipView = scrollView.contentView
        lastOrigin = clipView.bounds.origin
        clipView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main
        ) { [weak self, weak clipView] _ in
            guard let self, let clipView else { return }
            let origin = clipView.bounds.origin
            guard origin != self.lastOrigin else { return }
            self.lastOrigin = origin
            self.showWhileScrolling()
        }
    }

    private func showWhileScrolling() {
        isScrolling = true
        needsDisplay = true
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isScrolling = false
            self?.needsDisplay = true
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        pointerOnTrack = true
        needsDisplay = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        pointerOnTrack = false
        needsDisplay = true
        super.mouseExited(with: event)
    }

    override func drawKnob() {
        guard pointerOnTrack || isScrolling else { return }
        let knob = rect(for: .knob)
        guard !knob.isEmpty else { return }
        let vertical = bounds.height > bounds.width
        let verticalWidth: CGFloat = 7
        let visibleKnob = vertical
            ? knob.insetBy(dx: (knob.width - verticalWidth) / 2, dy: 0)
            : knob.insetBy(dx: 0, dy: knob.height * 0.25)
        NSColor.labelColor.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: visibleKnob, xRadius: 4, yRadius: 4).fill()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Keep the track transparent; AppKit still owns the hit target and fade.
    }
}

enum ThinScrollAxis { case vertical, horizontal }

private struct ThinScrollIndicatorInstaller: NSViewRepresentable {
    let axis: ThinScrollAxis

    func makeNSView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.axis = axis
        return view
    }

    func updateNSView(_ view: InstallerView, context: Context) {
        view.axis = axis
        view.scheduleInstall()
    }

    final class InstallerView: NSView {
        var axis: ThinScrollAxis = .vertical
        private weak var configuredScrollView: NSScrollView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleInstall()
        }

        func scheduleInstall() {
            DispatchQueue.main.async { [weak self] in self?.install() }
        }

        private func install() {
            guard let window, let root = window.contentView else { return }
            if let configuredScrollView, configuredScrollView.window === window,
               (axis == .vertical ? configuredScrollView.verticalScroller
                                  : configuredScrollView.horizontalScroller) is ThinOverlayScroller {
                return
            }
            let point = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
            let candidates = allScrollViews(in: root).filter { scrollView in
                let frame = scrollView.convert(scrollView.bounds, to: nil)
                guard frame.contains(point) else { return false }
                switch axis {
                case .vertical: return scrollView.hasVerticalScroller || scrollView.verticalScroller != nil
                case .horizontal: return scrollView.hasHorizontalScroller || scrollView.horizontalScroller != nil
                }
            }
            guard let scrollView = candidates.min(by: {
                $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
            }) else { return }
            if configuredScrollView === scrollView,
               (axis == .vertical ? scrollView.verticalScroller : scrollView.horizontalScroller) is ThinOverlayScroller {
                return
            }
            // Overlay scrollers fade out automatically, then appear on scrolling
            // or when the pointer reaches their narrow edge region.
            scrollView.scrollerStyle = .overlay
            switch axis {
            case .vertical:
                let scroller = ThinOverlayScroller()
                scrollView.verticalScroller = scroller
                scrollView.hasVerticalScroller = true
                scroller.observeScrolling(in: scrollView)
            case .horizontal:
                let scroller = ThinOverlayScroller()
                scrollView.horizontalScroller = scroller
                scrollView.hasHorizontalScroller = true
                scroller.observeScrolling(in: scrollView)
            }
            configuredScrollView = scrollView
        }

        private func allScrollViews(in view: NSView) -> [NSScrollView] {
            var result: [NSScrollView] = []
            if let scrollView = view as? NSScrollView { result.append(scrollView) }
            for child in view.subviews { result += allScrollViews(in: child) }
            return result
        }
    }
}

extension View {
    func thinAutoScrollIndicators(_ axis: ThinScrollAxis) -> some View {
        background(ThinScrollIndicatorInstaller(axis: axis).frame(width: 0, height: 0))
    }
}
