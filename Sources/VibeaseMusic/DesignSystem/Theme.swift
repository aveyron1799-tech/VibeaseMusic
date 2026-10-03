import AppKit
import SwiftUI

/// Design tokens. Every token resolves against the user's chosen `UITheme`:
/// "Washi" (和纸: rice paper, sumi ink and a single vermilion seal colour) or
/// "Classic" (system materials and NetEase red).
///
/// Tokens read `SettingsManager.uiTheme`, an observable property, so any view
/// that reads a token in `body` re-renders when the theme changes.
@MainActor
enum Theme {
    static var current: UITheme { SettingsManager.shared.uiTheme }
    static var isWashi: Bool { current == .washi }

    // MARK: Colour

    /// The only saturated colour in the interface.
    static var accent: Color { isWashi ? Washi.accent : Classic.accent }
    static var accentDeep: Color { isWashi ? Washi.accentDeep : Classic.accentDeep }
    static var accentGradient: LinearGradient { isWashi ? Washi.accentGradient : Classic.accentGradient }

    /// Text, strokes and quiet controls.
    static var ink: Color { isWashi ? Washi.ink : Classic.ink }
    /// Fill of primary controls (play buttons, prominent buttons, selected chips).
    static var inkFill: Color { isWashi ? Washi.ink : Classic.accent }
    /// Text/glyphs drawn on top of `inkFill`.
    static var onInk: Color { isWashi ? Washi.onInk : Classic.onInk }
    /// VIP marks.
    static var gold: Color { isWashi ? Washi.gold : Classic.accent }

    /// Page background.
    static var paper: Color { isWashi ? Washi.paper : Classic.paper }
    /// Sidebar background, like the next sheet underneath.
    static var paperDeep: Color { isWashi ? Washi.paperDeep : Classic.paperDeep }
    /// Raised sheet for cards, popovers, the player bar.
    static var sheet: Color { isWashi ? Washi.sheet : Classic.sheet }
    /// Hairline edge for sheets.
    static var hairline: Color { isWashi ? Washi.hairline : Classic.hairline }
    /// Faint wash used for hover and selection.
    static var wash: Color { isWashi ? Washi.wash : Classic.wash }
    static var shadow: Color { isWashi ? Washi.shadow : Classic.shadow }
    /// Window background behind the title bar. Stable instances, so callers can
    /// skip redundant (and redraw-triggering) assignments by identity.
    static var windowBackground: NSColor { isWashi ? Washi.paperNS : .windowBackgroundColor }

    private enum Washi {
        /// 朱 — seal-paste vermilion.
        static let accent = dynamic(light: (0.761, 0.255, 0.176), dark: (0.851, 0.361, 0.267))
        static let accentDeep = dynamic(light: (0.620, 0.188, 0.133), dark: (0.741, 0.275, 0.200))
        static let accentGradient = LinearGradient(
            colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing
        )
        /// 墨 — warm sumi ink.
        static let ink = dynamic(light: (0.165, 0.153, 0.133), dark: (0.918, 0.894, 0.847))
        static let onInk = dynamic(light: (0.969, 0.957, 0.929), dark: (0.110, 0.106, 0.098))
        /// 金 — faded gold leaf.
        static let gold = dynamic(light: (0.659, 0.522, 0.298), dark: (0.800, 0.671, 0.443))
        /// 纸 — page paper.
        static let paperNS = dynamicNS(light: (0.957, 0.941, 0.906, 1), dark: (0.110, 0.106, 0.098, 1))
        static let paper = Color(nsColor: paperNS)
        static let paperDeep = dynamic(light: (0.929, 0.910, 0.867), dark: (0.086, 0.082, 0.075))
        static let sheet = dynamic(light: (0.984, 0.976, 0.957), dark: (0.149, 0.143, 0.133))
        static let hairline = dynamic(light: (0.165, 0.153, 0.133, 0.10), dark: (0.918, 0.894, 0.847, 0.10))
        static let wash = dynamic(light: (0.165, 0.153, 0.133, 0.055), dark: (0.918, 0.894, 0.847, 0.065))
        /// Warm shadow (never pure black on paper).
        static let shadow = dynamic(light: (0.24, 0.17, 0.09, 0.16), dark: (0, 0, 0, 0.45))
    }

    private enum Classic {
        /// NetEase red, tuned slightly warmer for macOS.
        static let accent = Color(red: 0.925, green: 0.286, blue: 0.286) // #EC4949
        static let accentDeep = Color(red: 0.788, green: 0.161, blue: 0.161) // #C92929
        static let accentGradient = LinearGradient(
            colors: [Color(red: 0.973, green: 0.357, blue: 0.357), accentDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let ink = Color(nsColor: .labelColor)
        static let onInk = Color.white
        static let paper = Color(nsColor: .windowBackgroundColor)
        /// Transparent so the native sidebar material shows through.
        static let paperDeep = Color.clear
        static let sheet = Color(nsColor: .controlBackgroundColor)
        static let hairline = Color.primary.opacity(0.08)
        static let wash = Color.primary.opacity(0.06)
        static let shadow = Color.black.opacity(0.15)
    }

    nonisolated private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        dynamic(light: (light.0, light.1, light.2, 1), dark: (dark.0, dark.1, dark.2, 1))
    }

    nonisolated private static func dynamic(light: (Double, Double, Double, Double),
                                            dark: (Double, Double, Double, Double)) -> Color {
        Color(nsColor: dynamicNS(light: light, dark: dark))
    }

    nonisolated private static func dynamicNS(light: (Double, Double, Double, Double),
                                              dark: (Double, Double, Double, Double)) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        }
    }

    // MARK: Metrics

    @MainActor enum Radius {
        static var badge: CGFloat { isWashi ? 3 : 4 }
        static var small: CGFloat { isWashi ? 4 : 6 }
        static var standard: CGFloat { isWashi ? 6 : 8 }
        static var large: CGFloat { isWashi ? 10 : 12 }
        static var panel: CGFloat { isWashi ? 14 : 20 }
    }

    @MainActor enum Layout {
        static var contentInset: CGFloat { isWashi ? 32 : 24 }
        static var cardSize: CGFloat { isWashi ? 156 : 160 }
        static let sidebarWidth: CGFloat = 220
        static var playerBarHeight: CGFloat { isWashi ? 60 : 56 }
        static let minWindowWidth: CGFloat = 1020
        static let minWindowHeight: CGFloat = 640
        static let defaultWindowWidth: CGFloat = 1220
        static let defaultWindowHeight: CGFloat = 800
    }
}

extension Font {
    /// Songti (宋体) — the editorial serif voice for titles, lyrics and numerals
    /// in the Washi theme; the system face in Classic.
    @MainActor
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Theme.isWashi ? .custom("Songti SC", size: size).weight(weight) : .system(size: size, weight: weight)
    }
}

/// Motion tokens. In Washi, movement is unhurried: things settle like ink,
/// never bounce hard.
@MainActor
enum AppAnimation {
    static var quick: Animation { .easeOut(duration: Theme.isWashi ? 0.18 : 0.15) }
    static var standard: Animation { .easeInOut(duration: Theme.isWashi ? 0.3 : 0.25) }
    static var smooth: Animation { .easeInOut(duration: Theme.isWashi ? 0.45 : 0.35) }
    static var spring: Animation {
        Theme.isWashi ? .spring(response: 0.42, dampingFraction: 0.82) : .spring(response: 0.35, dampingFraction: 0.7)
    }
    static var bouncy: Animation {
        Theme.isWashi ? .spring(response: 0.5, dampingFraction: 0.7) : .spring(response: 0.4, dampingFraction: 0.6)
    }
    static var snappy: Animation {
        Theme.isWashi ? .spring(response: 0.3, dampingFraction: 0.86) : .spring(response: 0.25, dampingFraction: 0.8)
    }
    /// For things that should feel like breathing.
    static let breath = Animation.easeInOut(duration: 0.9)

    static let staggerDelay = 0.045
    static let maxStaggerDelay = 0.45

    static func stagger(for index: Int) -> Double {
        min(Double(index) * staggerDelay, maxStaggerDelay)
    }
}

@MainActor
extension View {
    /// Floating surface: a raised sheet of paper in Washi (warm fill, ink
    /// hairline, soft warm shadow), Liquid Glass / material in Classic.
    @ViewBuilder
    func compatGlass(interactive: Bool = false, in shape: some InsettableShape) -> some View {
        if Theme.isWashi {
            background {
                shape.fill(Theme.sheet)
                    .overlay(PaperGrain(opacity: 0.5).clipShape(shape))
                    .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 0.75))
                    .shadow(color: Theme.shadow, radius: 14, y: 6)
            }
        } else if #available(macOS 26.0, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }

    /// Match the sidebar: show the vertical indicator while scrolling or
    /// hovering over its track, rather than while hovering anywhere in the page.
    func hoverScrollIndicators() -> some View {
        thinAutoScrollIndicators(.vertical)
    }
}
