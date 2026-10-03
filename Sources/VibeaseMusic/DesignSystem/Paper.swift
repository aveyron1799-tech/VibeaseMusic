import AppKit
import SwiftUI

// MARK: - Paper grain

/// Procedurally drawn washi fibres and speckles, rendered once per appearance
/// and tiled. Seeded so the texture never shimmers between launches.
@MainActor
enum PaperTexture {
    private static var cache: [Bool: NSImage] = [:]

    static func image(dark: Bool) -> NSImage {
        if let cached = cache[dark] { return cached }
        let image = render(dark: dark)
        cache[dark] = image
        return image
    }

    private struct SeededRandom {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53)
        }
        mutating func range(_ lower: Double, _ upper: Double) -> Double {
            lower + (upper - lower) * next()
        }
    }

    private static func render(dark: Bool) -> NSImage {
        let points: CGFloat = 320
        let scale: CGFloat = 2
        let pixels = Int(points * scale)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
            bytesPerRow: pixels * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return NSImage() }
        ctx.scaleBy(x: scale, y: scale)

        var rng = SeededRandom(state: dark ? 0xD0C0_FFEE : 0x5EED_CAFE)
        let tone: (CGFloat, CGFloat, CGFloat) = dark ? (0.95, 0.92, 0.86) : (0.30, 0.22, 0.12)
        func color(_ alpha: Double) -> CGColor {
            CGColor(red: tone.0, green: tone.1, blue: tone.2, alpha: alpha * (dark ? 0.7 : 1))
        }

        // Speckles: pulp and tiny inclusions.
        for _ in 0..<2600 {
            let x = rng.range(0, Double(points)), y = rng.range(0, Double(points))
            let r = rng.range(0.2, 0.75)
            ctx.setFillColor(color(rng.range(0.025, 0.09)))
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        }

        // Long kozo fibres — the signature of hand-made paper.
        ctx.setLineCap(.round)
        for _ in 0..<110 {
            let x = rng.range(-20, Double(points) + 20), y = rng.range(-20, Double(points) + 20)
            let angle = rng.range(0, .pi * 2)
            let length = rng.range(14, 70)
            let bend = rng.range(-14, 14)
            let end = CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length)
            let mid = CGPoint(x: (x + end.x) / 2 + cos(angle + .pi / 2) * bend,
                              y: (y + end.y) / 2 + sin(angle + .pi / 2) * bend)
            ctx.setStrokeColor(color(rng.range(0.018, 0.045)))
            ctx.setLineWidth(rng.range(0.3, 0.8))
            // Draw each fibre at every wrap offset so the tile repeats seamlessly.
            for dx in [-points, 0, points] {
                for dy in [-points, 0, points] {
                    ctx.move(to: CGPoint(x: x + dx, y: y + dy))
                    ctx.addQuadCurve(to: CGPoint(x: end.x + dx, y: end.y + dy),
                                     control: CGPoint(x: mid.x + dx, y: mid.y + dy))
                }
            }
            ctx.strokePath()
        }

        guard let cgImage = ctx.makeImage() else { return NSImage() }
        return NSImage(cgImage: cgImage, size: NSSize(width: points, height: points))
    }
}

struct PaperGrain: View {
    var opacity: Double = 1
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: PaperTexture.image(dark: colorScheme == .dark))
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Page background

struct PaperBackground: View {
    enum Tone { case page, sidebar }
    var tone: Tone = .page
    /// An optional watercolour wash bleeding in from the corners.
    var wash: Color?

    var body: some View {
        ZStack {
            (tone == .page ? Theme.paper : Theme.paperDeep)
            if let wash {
                RadialGradient(colors: [wash.opacity(0.16), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 620)
                RadialGradient(colors: [wash.opacity(0.08), .clear],
                               center: .bottomLeading, startRadius: 0, endRadius: 520)
            }
            PaperGrain()
            // Light falls a little brighter in the middle of the sheet.
            RadialGradient(colors: [.white.opacity(0.05), .clear, Theme.shadow.opacity(0.18)],
                           center: .center, startRadius: 120, endRadius: 1100)
                .blendMode(.softLight)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Brush stroke

/// A single horizontal brush mark: heavy where the brush lands, dry where it lifts.
struct BrushStroke: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.01, y: rect.minY + h * 0.62))
        p.addCurve(to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.38),
                   control1: CGPoint(x: rect.minX + w * 0.18, y: rect.minY - h * 0.05),
                   control2: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.08))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.01, y: rect.minY + h * 0.62),
                   control1: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.86),
                   control2: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 1.05))
        p.closeSubpath()
        return p
    }
}

/// A brush mark that paints itself in from the left when `painted` turns on.
struct PaintedBrush: View {
    var painted: Bool
    var color: Color = Theme.ink

    var body: some View {
        BrushStroke()
            .fill(color)
            .scaleEffect(x: painted ? 1 : 0.001, anchor: .leading)
            .opacity(painted ? 1 : 0)
            .animation(painted ? .easeOut(duration: 0.5) : .easeIn(duration: 0.2), value: painted)
            .allowsHitTesting(false)
    }
}

// MARK: - Ensō

/// 圆相 — a one-stroke zen circle. `progress` controls how far the brush has
/// travelled, which lets it double as a calm progress ring.
struct Enso: View {
    var progress: Double = 1
    var lineWidth: CGFloat = 6
    var color: Color = Theme.ink
    /// Where the brush lands, in degrees (0 = 3 o'clock, clockwise).
    var startAngle: Double = -100
    var sweep: Double = 338

    var body: some View {
        Canvas { context, size in
            let travelled = min(max(progress, 0), 1)
            guard travelled > 0.001 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - lineWidth
            let steps = max(Int(220 * travelled), 2)
            let start = startAngle * .pi / 180
            let total = sweep * travelled * .pi / 180

            func point(_ angle: Double, _ r: CGFloat) -> CGPoint {
                CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            }

            // Main body of the stroke: lands heavy, thins out as ink runs dry.
            for i in 0..<steps {
                let t0 = Double(i) / Double(steps), t1 = Double(i + 1) / Double(steps)
                let globalT = t0 * travelled
                let landing = min(globalT / 0.05, 1)
                let width = lineWidth * (0.45 + 0.55 * landing) * (1.08 - 0.62 * globalT)
                let wobble = sin(globalT * 19) * lineWidth * 0.06
                var path = Path()
                path.move(to: point(start + total * t0, radius + wobble))
                path.addLine(to: point(start + total * t1, radius + wobble))
                let alpha = globalT > 0.78 ? 1 - (globalT - 0.78) * 2.2 : 1
                context.stroke(path, with: .color(color.opacity(0.92 * alpha)),
                               style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            // Dry-brush bristles (飞白) that outlast the body near the tail.
            for (offset, fade, extent) in [(-0.42, 0.55, 1.0), (0.38, 0.45, 0.96), (0.05, 0.35, 1.0)] {
                var path = Path()
                let r = radius + lineWidth * offset
                path.addArc(center: center, radius: r,
                            startAngle: .radians(start + total * 0.55),
                            endAngle: .radians(start + total * extent),
                            clockwise: false)
                context.stroke(path, with: .color(color.opacity(fade * 0.6)),
                               style: StrokeStyle(lineWidth: max(lineWidth * 0.12, 0.6), lineCap: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Loading indicator: an ensō drawn, held, and lifted, over and over.
struct InkLoader: View {
    var size: CGFloat = 34
    var color: Color = Theme.ink

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { context in
            let cycle = 2.4
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            let drawn = min(phase / 0.6, 1)
            let eased = 1 - pow(1 - drawn, 3)
            let fade = phase > 0.8 ? 1 - (phase - 0.8) / 0.2 : 1
            Enso(progress: eased, lineWidth: size * 0.11, color: color)
                .opacity(fade)
                .rotationEffect(.degrees(phase * 24))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("加载中")
    }
}

// MARK: - Seal

/// 印 — a vermilion seal impression with gently eroded edges.
struct SealStamp: View {
    let text: String
    var size: CGFloat = 22
    var color: Color = Theme.accent
    /// Vertical layout for two-character seals (e.g. a solar term name).
    var vertical = false

    var body: some View {
        let characters = Array(text)
        Group {
            if vertical {
                VStack(spacing: -size * 0.02) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                    }
                }
            } else {
                Text(text)
            }
        }
        .font(.serif(vertical ? size * 0.42 : size * 0.52, .bold))
        .foregroundStyle(Color(red: 0.99, green: 0.96, blue: 0.92))
        .frame(width: size, height: vertical ? size * 0.5 * CGFloat(max(characters.count, 1)) + size * 0.24 : size)
        .background(color, in: RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .strokeBorder(Color(red: 0.99, green: 0.96, blue: 0.92).opacity(0.55), lineWidth: max(size * 0.035, 0.6))
                .padding(size * 0.08)
        )
        .overlay(PaperGrain(opacity: 1).blendMode(.destinationOut))
        .compositingGroup()
        .accessibilityLabel(text)
    }
}

// MARK: - Ink bloom

/// A drop of ink spreading into paper, triggered whenever `trigger` changes.
struct InkBloomModifier: ViewModifier {
    let trigger: Int
    var color: Color = Theme.ink
    var scale: CGFloat = 2.3

    @State private var blooms: [Int] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    ForEach(blooms, id: \.self) { _ in
                        InkBloomDrop(color: color, scale: scale)
                    }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) {
                guard !reduceMotion else { return }
                let id = trigger
                blooms.append(id)
                if blooms.count > 3 { blooms.removeFirst() }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.3))
                    blooms.removeAll { $0 == id }
                }
            }
    }
}

private struct InkBloomDrop: View {
    let color: Color
    let scale: CGFloat
    @State private var spread = false

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.32), color.opacity(0.12), .clear],
                                 center: .center, startRadius: 0, endRadius: 30))
            .scaleEffect(spread ? scale : 0.5)
            .opacity(spread ? 0 : 1)
            .blur(radius: spread ? 5 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) { spread = true }
            }
    }
}

extension View {
    func inkBloom(trigger: Int, color: Color = Theme.ink, scale: CGFloat = 2.3) -> some View {
        modifier(InkBloomModifier(trigger: trigger, color: color, scale: scale))
    }

    /// A sheet of paper lying on the page: no shadow until lifted.
    func paperSheet(cornerRadius: CGFloat = Theme.Radius.large, lifted: Bool = false) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.sheet)
                .overlay(PaperGrain(opacity: 0.6)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.75))
                .shadow(color: Theme.shadow.opacity(lifted ? 1 : 0.35),
                        radius: lifted ? 16 : 3, y: lifted ? 8 : 1)
        }
    }
}

// MARK: - Distant mountains

/// 远山 — layered ink-wash ridgelines, painted procedurally and very faint.
struct InkMountains: View {
    var color: Color = Theme.ink
    var seed: Double = 1.7

    var body: some View {
        Canvas { context, size in
            let layers: [(height: Double, opacity: Double, frequency: Double)] = [
                (0.92, 0.05, 1.3), (0.70, 0.075, 2.1), (0.48, 0.11, 3.2),
            ]
            for (index, layer) in layers.enumerated() {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                let phase = seed * Double(index + 1)
                let steps = 90
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    let ridge = 0.55 * sin(t * .pi * layer.frequency + phase)
                        + 0.28 * sin(t * .pi * layer.frequency * 2.7 + phase * 1.9)
                        + 0.12 * sin(t * .pi * layer.frequency * 6.1 + phase * 0.7)
                    let peak = (0.5 + 0.5 * ridge) * layer.height
                    let y = size.height * (1 - peak * (0.35 + 0.65 * sin(t * .pi)))
                    path.addLine(to: CGPoint(x: t * size.width, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [color.opacity(layer.opacity), color.opacity(layer.opacity * 0.15)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)
                ))
            }
        }
        .blur(radius: 1.2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Seasons

/// The 24 solar terms (二十四节气) with a line of classical verse for each.
enum SolarTerm {
    struct Term {
        let name: String
        let verse: String
    }

    private static let table: [(month: Int, day: Int, term: Term)] = [
        (1, 6, Term(name: "小寒", verse: "小寒连大吕，欢鹊垒新巢")),
        (1, 20, Term(name: "大寒", verse: "旧雪未及消，新雪又拥户")),
        (2, 4, Term(name: "立春", verse: "律回岁晚冰霜少，春到人间草木知")),
        (2, 19, Term(name: "雨水", verse: "好雨知时节，当春乃发生")),
        (3, 6, Term(name: "惊蛰", verse: "微雨众卉新，一雷惊蛰始")),
        (3, 21, Term(name: "春分", verse: "春风如贵客，一到便繁华")),
        (4, 5, Term(name: "清明", verse: "梨花风起正清明，游子寻春半出城")),
        (4, 20, Term(name: "谷雨", verse: "谷雨春光晓，山川黛色青")),
        (5, 6, Term(name: "立夏", verse: "绿树阴浓夏日长，楼台倒影入池塘")),
        (5, 21, Term(name: "小满", verse: "最爱垄头麦，迎风笑落红")),
        (6, 6, Term(name: "芒种", verse: "时雨及芒种，四野皆插秧")),
        (6, 21, Term(name: "夏至", verse: "绿筠尚含粉，圆荷始散芳")),
        (7, 7, Term(name: "小暑", verse: "倏忽温风至，因循小暑来")),
        (7, 23, Term(name: "大暑", verse: "赤日几时过，清风无处寻")),
        (8, 8, Term(name: "立秋", verse: "乳鸦啼散玉屏空，一枕新凉一扇风")),
        (8, 23, Term(name: "处暑", verse: "离离暑云散，袅袅凉风起")),
        (9, 8, Term(name: "白露", verse: "露从今夜白，月是故乡明")),
        (9, 23, Term(name: "秋分", verse: "金气秋分，风清露冷秋期半")),
        (10, 8, Term(name: "寒露", verse: "袅袅凉风动，凄凄寒露零")),
        (10, 23, Term(name: "霜降", verse: "霜降水返壑，风落木归山")),
        (11, 7, Term(name: "立冬", verse: "细雨生寒未有霜，庭前木叶半青黄")),
        (11, 22, Term(name: "小雪", verse: "花雪随风不厌看，更多还肯失林峦")),
        (12, 7, Term(name: "大雪", verse: "晚来天欲雪，能饮一杯无")),
        (12, 22, Term(name: "冬至", verse: "天时人事日相催，冬至阳生春又来")),
    ]

    static func current(_ date: Date = .now, calendar: Calendar = .current) -> Term {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let key = month * 100 + day
        // Before 小寒 (Jan 6) we are still in the previous year's 冬至.
        return table.last { $0.month * 100 + $0.day <= key }?.term ?? table[table.count - 1].term
    }
}

// MARK: - Artwork wash

/// Watercolour bleed of an artwork's dominant colour across the top of a page.
struct ArtworkWash: View {
    let url: URL?
    var height: CGFloat = 420

    @State private var color: Color?

    var body: some View {
        ZStack {
            if let color {
                RadialGradient(colors: [color.opacity(0.22), color.opacity(0.06), .clear],
                               center: UnitPoint(x: 0.12, y: 0.05), startRadius: 0, endRadius: 640)
                    .transition(.opacity)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 1), value: color)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: url) {
            guard let url, let image = await ImageCache.shared.image(for: url) else {
                color = nil
                return
            }
            guard !Task.isCancelled else { return }
            color = ArtworkPalette.extract(from: image, cacheKey: url.absoluteString).primary
        }
    }
}

/// Small spaced label above a page title, e.g. "歌单 · PLAYLIST".
struct Eyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.accent).frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .tracking(2.5)
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
    }
}

/// Inline filter field drawn as a hairline capsule.
struct InkFilterField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var width: CGFloat = 140

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.ink.opacity(0.45))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focused)
                .frame(width: width)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(focused ? Theme.sheet : .clear))
        .overlay(Capsule().strokeBorder(focused ? Theme.ink.opacity(0.3) : Theme.hairline, lineWidth: 0.75))
        .animation(AppAnimation.quick, value: focused)
    }
}
