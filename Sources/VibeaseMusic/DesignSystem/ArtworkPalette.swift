import AppKit
import SwiftUI

/// Dominant-color extraction for artwork-driven backgrounds
/// (kaset's ColorExtractor approach: tiny bitmap, saturation-weighted averages).
struct ArtworkColors: Equatable {
    var primary: Color
    var secondary: Color

    static let fallback = ArtworkColors(
        primary: Color(red: 0.16, green: 0.16, blue: 0.20),
        secondary: Color(red: 0.09, green: 0.09, blue: 0.12)
    )
}

enum ArtworkPalette {
    private static var cache: [String: ArtworkColors] = [:]

    @MainActor
    static func extract(from image: NSImage, cacheKey: String) -> ArtworkColors {
        if let cached = cache[cacheKey] {
            return cached
        }
        let colors = compute(from: image)
        if cache.count > 200 { cache.removeAll() }
        cache[cacheKey] = colors
        return colors
    }

    private static func compute(from image: NSImage) -> ArtworkColors {
        let size = 10
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return .fallback }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                   from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        var samples: [(h: CGFloat, s: CGFloat, b: CGFloat, weight: CGFloat)] = []
        for x in 0..<size {
            for y in 0..<size {
                guard let color = bitmap.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB) else { continue }
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                // Weight vivid mid-brightness pixels highest.
                let weight = s * (1 - abs(b - 0.55))
                samples.append((h, s, b, max(weight, 0.01)))
            }
        }
        guard !samples.isEmpty else { return .fallback }

        // Dominant hue = weighted circular mean.
        var sinSum: CGFloat = 0, cosSum: CGFloat = 0, weightSum: CGFloat = 0
        var satSum: CGFloat = 0, brightSum: CGFloat = 0
        for sample in samples {
            let angle = sample.h * 2 * .pi
            sinSum += sin(angle) * sample.weight
            cosSum += cos(angle) * sample.weight
            satSum += sample.s * sample.weight
            brightSum += sample.b * sample.weight
            weightSum += sample.weight
        }
        var hue = atan2(sinSum, cosSum) / (2 * .pi)
        if hue < 0 { hue += 1 }
        let saturation = min(satSum / weightSum * 1.15, 0.72)
        let brightness = brightSum / weightSum

        let primary = Color(hue: hue, saturation: saturation,
                            brightness: min(max(brightness, 0.32), 0.5))
        let secondary = Color(hue: (hue + 0.06).truncatingRemainder(dividingBy: 1),
                              saturation: min(saturation * 1.1, 0.8),
                              brightness: min(max(brightness * 0.5, 0.12), 0.26))
        return ArtworkColors(primary: primary, secondary: secondary)
    }
}
