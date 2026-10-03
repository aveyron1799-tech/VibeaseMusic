// Classic theme: the original interface, kept intact alongside Washi.
import SwiftUI

/// Cards that scale up on hover, scale down on press, with a soft shadow.
struct ClassicInteractiveCardStyle: ButtonStyle {
    var showShadow = true
    var hoverScale: CGFloat = 1.02
    var pressScale: CGFloat = 0.98

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : (isHovering ? hoverScale : 1.0))
            .shadow(
                color: showShadow && isHovering ? .black.opacity(0.15) : .clear,
                radius: isHovering ? 12 : 0,
                x: 0,
                y: isHovering ? 4 : 0
            )
            .animation(ClassicAnimation.spring, value: configuration.isPressed)
            .animation(ClassicAnimation.spring, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// List rows with a hover background highlight.
struct ClassicInteractiveRowStyle: ButtonStyle {
    var cornerRadius: CGFloat = ClassicTheme.Radius.standard
    var hoverColor: Color = .primary.opacity(0.06)

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovering || configuration.isPressed ? hoverColor : .clear)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(ClassicAnimation.quick, value: configuration.isPressed)
            .animation(ClassicAnimation.quick, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// Subtle press feedback for icon buttons.
struct ClassicPressableButtonStyle: ButtonStyle {
    var pressScale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(ClassicAnimation.quick, value: configuration.isPressed)
    }
}

/// Filter chips (category pickers).
struct ClassicChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isSelected
                        ? AnyShapeStyle(ClassicTheme.accent)
                        : AnyShapeStyle(.primary.opacity(isHovering ? 0.1 : 0.06))
                )
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovering ? 1.03 : 1.0))
            .animation(ClassicAnimation.spring, value: configuration.isPressed)
            .animation(ClassicAnimation.spring, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension ButtonStyle where Self == ClassicInteractiveCardStyle {
    static var classicInteractiveCard: ClassicInteractiveCardStyle { ClassicInteractiveCardStyle() }
}

extension ButtonStyle where Self == ClassicInteractiveRowStyle {
    static var classicInteractiveRow: ClassicInteractiveRowStyle { ClassicInteractiveRowStyle() }
}

extension ButtonStyle where Self == ClassicPressableButtonStyle {
    static var classicPressable: ClassicPressableButtonStyle { ClassicPressableButtonStyle() }
}

extension ButtonStyle where Self == ClassicChipButtonStyle {
    static func classicChip(isSelected: Bool) -> ClassicChipButtonStyle { ClassicChipButtonStyle(isSelected: isSelected) }
}
