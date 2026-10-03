import AppKit
import SwiftUI

/// Design tokens for the "Washi" (和纸) language: rice paper, sumi ink and a
/// single vermilion seal colour, used sparingly.
enum Theme {
    // MARK: Colour

    /// 朱 — seal-paste vermilion. The only saturated colour in the interface.
    static let accent = dynamic(light: (0.761, 0.255, 0.176), dark: (0.851, 0.361, 0.267))
    static let accentDeep = dynamic(light: (0.620, 0.188, 0.133), dark: (0.741, 0.275, 0.200))
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// 墨 — warm sumi ink used for text, strokes and filled controls.
    static let ink = dynamic(light: (0.165, 0.153, 0.133), dark: (0.918, 0.894, 0.847))
    /// Text/controls drawn on top of `ink` fills.
    static let onInk = dynamic(light: (0.969, 0.957, 0.929), dark: (0.110, 0.106, 0.098))
    /// 金 — faded gold leaf for VIP marks.
    static let gold = dynamic(light: (0.659, 0.522, 0.298), dark: (0.800, 0.671, 0.443))

    /// 纸 — page paper.
    static let paper = dynamic(light: (0.957, 0.941, 0.906), dark: (0.110, 0.106, 0.098))
    /// Slightly deeper paper for the sidebar, like the next sheet underneath.
    static let paperDeep = dynamic(light: (0.929, 0.910, 0.867), dark: (0.086, 0.082, 0.075))
    /// Raised sheet for cards, popovers, the player bar.
    static let sheet = dynamic(light: (0.984, 0.976, 0.957), dark: (0.149, 0.143, 0.133))
    /// Hairline ink edge for sheets.
    static let hairline = dynamic(light: (0.165, 0.153, 0.133, 0.10), dark: (0.918, 0.894, 0.847, 0.10))
    /// Faint ink wash used for hover and selection.
    static let wash = dynamic(light: (0.165, 0.153, 0.133, 0.055), dark: (0.918, 0.894, 0.847, 0.065))
    /// Warm shadow colour (never pure black on paper).
    static let shadow = dynamic(light: (0.24, 0.17, 0.09, 0.16), dark: (0, 0, 0, 0.45))

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        dynamic(light: (light.0, light.1, light.2, 1), dark: (dark.0, dark.1, dark.2, 1))
    }

    private static func dynamic(light: (Double, Double, Double, Double),
                                dark: (Double, Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    // MARK: Metrics

    enum Radius {
        static let badge: CGFloat = 3
        static let small: CGFloat = 4
        static let standard: CGFloat = 6
        static let large: CGFloat = 10
        static let panel: CGFloat = 14
    }

    enum Layout {
        static let contentInset: CGFloat = 32
        static let cardSize: CGFloat = 156
        static let sidebarWidth: CGFloat = 220
        static let playerBarHeight: CGFloat = 60
        static let minWindowWidth: CGFloat = 1020
        static let minWindowHeight: CGFloat = 640
        static let defaultWindowWidth: CGFloat = 1220
        static let defaultWindowHeight: CGFloat = 800
    }
}

extension Font {
    /// Songti (宋体) — the editorial serif voice for titles, lyrics and numerals.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Songti SC", size: size).weight(weight)
    }
}

/// Motion tokens. Movement is unhurried: things settle like ink, never bounce hard.
enum AppAnimation {
    static let quick = Animation.easeOut(duration: 0.18)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let smooth = Animation.easeInOut(duration: 0.45)
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.86)
    /// For things that should feel like breathing.
    static let breath = Animation.easeInOut(duration: 0.9)

    static let staggerDelay = 0.045
    static let maxStaggerDelay = 0.45

    static func stagger(for index: Int) -> Double {
        min(Double(index) * staggerDelay, maxStaggerDelay)
    }
}

extension View {
    /// A raised sheet of paper: warm fill, ink hairline, soft warm shadow.
    /// (Kept under its historical name so every floating surface follows the theme.)
    func compatGlass(interactive: Bool = false, in shape: some InsettableShape) -> some View {
        background {
            shape.fill(Theme.sheet)
                .overlay(PaperGrain(opacity: 0.5).clipShape(shape))
                .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 0.75))
                .shadow(color: Theme.shadow, radius: 14, y: 6)
        }
    }

    /// Match the sidebar: show the vertical indicator while scrolling or
    /// hovering over its track, rather than while hovering anywhere in the page.
    func hoverScrollIndicators() -> some View {
        thinAutoScrollIndicators(.vertical)
    }
}
