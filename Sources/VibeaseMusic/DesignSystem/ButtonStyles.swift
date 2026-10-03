import SwiftUI

/// Cards lift off the page like a sheet of paper picked up by one corner.
struct InteractiveCardStyle: ButtonStyle {
    var showShadow = true
    var hoverScale: CGFloat = 1.0
    var pressScale: CGFloat = 0.985

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : hoverScale)
            .offset(y: isHovering && !configuration.isPressed ? -3 : 0)
            .animation(AppAnimation.spring, value: configuration.isPressed)
            .animation(AppAnimation.spring, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// List rows: a faint ink wash fades in beneath the row.
struct InteractiveRowStyle: ButtonStyle {
    var cornerRadius: CGFloat = Theme.Radius.standard
    var hoverColor: Color = Theme.wash

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovering || configuration.isPressed ? hoverColor : .clear)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
            .animation(AppAnimation.quick, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Subtle press feedback for icon buttons.
struct PressableButtonStyle: ButtonStyle {
    var pressScale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

/// Filter chips: selected chips are inked in, the rest are bare words.
struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? Theme.ink : (isHovering ? Theme.wash : .clear))
            )
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Theme.hairline, lineWidth: 0.75))
            .foregroundStyle(isSelected ? Theme.onInk : Theme.ink.opacity(0.78))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.snappy, value: isSelected)
            .animation(AppAnimation.quick, value: configuration.isPressed)
            .animation(AppAnimation.quick, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Primary action: an inked capsule. On hover, vermilion seeps in from below.
struct InkButtonStyle: ButtonStyle {
    var prominent = true

    @State private var isHovering = false
    @State private var presses = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .foregroundStyle(prominent ? Theme.onInk : Theme.ink)
            .background {
                if prominent {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Theme.ink)
                        Capsule().fill(Theme.accent)
                            .scaleEffect(y: isHovering ? 1 : 0.001, anchor: .bottom)
                            .opacity(isHovering ? 1 : 0)
                    }
                    .clipShape(Capsule())
                } else {
                    Capsule().fill(isHovering ? Theme.wash : .clear)
                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.22), lineWidth: 0.75))
                }
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .inkBloom(trigger: presses, color: prominent ? Theme.accent : Theme.ink, scale: 1.6)
            .animation(.easeOut(duration: 0.35), value: isHovering)
            .animation(AppAnimation.quick, value: configuration.isPressed)
            .onHover { isHovering = $0 }
            .onChange(of: configuration.isPressed) { _, pressed in
                if !pressed { presses += 1 }
            }
    }
}

extension ButtonStyle where Self == InteractiveCardStyle {
    static var interactiveCard: InteractiveCardStyle { InteractiveCardStyle() }
}

extension ButtonStyle where Self == InteractiveRowStyle {
    static var interactiveRow: InteractiveRowStyle { InteractiveRowStyle() }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static func chip(isSelected: Bool) -> ChipButtonStyle { ChipButtonStyle(isSelected: isSelected) }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
    static var inkOutline: InkButtonStyle { InkButtonStyle(prominent: false) }
}
