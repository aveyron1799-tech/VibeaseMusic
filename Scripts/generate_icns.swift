import AppKit
import CoreGraphics

// Builds AppIcon.icns / AppIcon.iconset / Resources/AppIcon_1024.png from a
// full-bleed square artwork. Usage: swift Scripts/generate_icns.swift [source.png]
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let rootDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent().path
let inputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "\(rootDir)/Resources/AppIconSource/washi-source.png"

guard let inputImage = NSImage(contentsOfFile: inputPath),
      let source = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Error: Could not load source image at \(inputPath)")
    exit(1)
}

let targetSize = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(_ size: Int) -> CGContext {
    CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

let context = makeContext(targetSize)
context.interpolationQuality = .high

// macOS icon grid: 824pt body centered in the 1024 canvas.
let iconSize: CGFloat = 824
let iconOrigin = (CGFloat(targetSize) - iconSize) / 2
let iconRect = CGRect(x: iconOrigin, y: iconOrigin, width: iconSize, height: iconSize)
let cornerRadius = iconSize * 0.2245
let squircle = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius,
                      cornerHeight: cornerRadius, transform: nil)

// Slight zoom so the generated art's soft outer falloff is cropped away.
let zoom: CGFloat = 1.02
let artSize = iconSize * zoom
let artRect = CGRect(x: iconRect.midX - artSize / 2, y: iconRect.midY - artSize / 2,
                     width: artSize, height: artSize)

// Soft contact shadow so the paper tile sits on the Dock.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24,
                  color: CGColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 0.28))
context.addPath(squircle)
context.setFillColor(CGColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(squircle)
context.clip()
context.draw(source, in: artRect)

// Top sheen: a soft glass highlight that fades out by mid-height.
let sheen = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray, locations: [0, 1])!
context.drawLinearGradient(sheen,
                           start: CGPoint(x: iconRect.midX, y: iconRect.maxY),
                           end: CGPoint(x: iconRect.midX, y: iconRect.midY + 60),
                           options: [])

// Bottom vignette to seat the artwork.
let vignette = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
    CGColor(red: 0.30, green: 0.20, blue: 0.08, alpha: 0.10),
] as CFArray, locations: [0, 1])!
context.drawLinearGradient(vignette,
                           start: CGPoint(x: iconRect.midX, y: iconRect.midY - 80),
                           end: CGPoint(x: iconRect.midX, y: iconRect.minY),
                           options: [])
context.restoreGState()

// Hairline inner rim so the edge reads on dark Docks.
context.saveGState()
context.addPath(squircle)
context.clip()
context.addPath(CGPath(roundedRect: iconRect.insetBy(dx: 1.5, dy: 1.5),
                       cornerWidth: cornerRadius - 1.5, cornerHeight: cornerRadius - 1.5,
                       transform: nil))
context.setStrokeColor(CGColor(red: 0.25, green: 0.18, blue: 0.10, alpha: 0.10))
context.setLineWidth(3)
context.strokePath()
context.restoreGState()

// Force the solid interior fully opaque: macOS wraps icons with partial alpha
// in an extra backing plate. Antialiased silhouette edges stay translucent.
if let bytes = context.data?.assumingMemoryBound(to: UInt8.self) {
    for pixel in 0..<(targetSize * targetSize) {
        let offset = pixel * 4
        let alpha = Int(bytes[offset + 3])
        if alpha >= 240, alpha < 255 {
            for channel in 0..<3 {
                bytes[offset + channel] = UInt8(min(255, Int(bytes[offset + channel]) * 255 / alpha))
            }
            bytes[offset + 3] = 255
        }
    }
}

let master = context.makeImage()!

func writePNG(_ image: CGImage, to path: String) {
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}

writePNG(master, to: "\(rootDir)/Resources/AppIcon_1024.png")
writePNG(master, to: "\(rootDir)/AppIcon.icon/Assets/AppIcon.png")
writePNG(master, to: "\(rootDir)/docs/icon.png")

let iconsetDir = "\(rootDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in sizes {
    let resized = makeContext(size)
    resized.interpolationQuality = .high
    resized.draw(master, in: CGRect(x: 0, y: 0, width: size, height: size))
    writePNG(resized.makeImage()!, to: "\(iconsetDir)/\(name)")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir, "-o", "\(rootDir)/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    print("Error: iconutil failed")
    exit(iconutil.terminationStatus)
}
print("Icon written to \(rootDir)/AppIcon.icns")
