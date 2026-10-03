import AppKit
import CoreGraphics

let inputPath = "/Users/mac/Projects/VibeaseMusic/Resources/AppIconPreviews/VibeaseMusic-transparent.png"
let rootDir = "/Users/mac/Projects/VibeaseMusic"

guard let inputImage = NSImage(contentsOfFile: inputPath),
      let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Error: Could not load source image")
    exit(1)
}

// The edited source has a transparent canvas around the artwork. Crop the icon
// itself so no canvas matte or generated speckles can enter the final icon.
let cropRect = CGRect(x: 107, y: 107, width: 1040, height: 1010)
guard let cropped = cgImage.cropping(to: cropRect) else {
    print("Error: Cropping failed")
    exit(1)
}

// Create 1024x1024 master canvas
let targetSize = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil,
    width: targetSize,
    height: targetSize,
    bitsPerComponent: 8,
    bytesPerRow: targetSize * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Error: CGContext creation failed")
    exit(1)
}

context.interpolationQuality = .high

// Standard macOS Big Sur icon size in 1024 canvas is 824x824 centered
let iconSize: CGFloat = 824.0
let iconOrigin: CGFloat = (CGFloat(targetSize) - iconSize) / 2.0 // 100.0
let iconRect = CGRect(x: iconOrigin, y: iconOrigin, width: iconSize, height: iconSize)

// The artwork already contains its rounded-square silhouette. This clip only
// cleans the extreme transparent edge; the .icns is packaged directly, without
// Icon Composer adding a second system border or backing plate.
let cornerRadius: CGFloat = iconSize * 0.2245
let squirclePath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

// Clip to clean squircle
context.saveGState()
context.addPath(squirclePath)
context.clip()

// Draw the cropped artwork scaled to fill the squircle
context.draw(cropped, in: iconRect)
context.restoreGState()

// Encode the solid artwork as opaque. The generated source carries alpha 253/254
// even in its solid interior; macOS otherwise treats it as a floating glyph and
// inserts a backing plate. Keep antialiased silhouette edges transparent.
if let bytes = context.data?.assumingMemoryBound(to: UInt8.self) {
    for pixel in 0..<(targetSize * targetSize) {
        let offset = pixel * 4
        let alpha = Int(bytes[offset + 3])
        if alpha >= 240 {
            for channel in 0..<3 {
                bytes[offset + channel] = UInt8(min(255, Int(bytes[offset + channel]) * 255 / alpha))
            }
            bytes[offset + 3] = 255
        }
    }
}

guard let masterCGImage = context.makeImage() else {
    print("Error: Master image creation failed")
    exit(1)
}

let masterRep = NSBitmapImageRep(cgImage: masterCGImage)
let masterPNG = masterRep.representation(using: .png, properties: [:])!

// Save master PNG
let masterPNGPath = "\(rootDir)/Resources/AppIcon_1024.png"
try! masterPNG.write(to: URL(fileURLWithPath: masterPNGPath))
print("Saved clean master icon: \(masterPNGPath)")

// Generate iconset
let iconsetDir = "\(rootDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in sizes {
    guard let resizeContext = CGContext(
        data: nil,
        width: item.size,
        height: item.size,
        bitsPerComponent: 8,
        bytesPerRow: item.size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    
    resizeContext.interpolationQuality = .high
    resizeContext.draw(masterCGImage, in: CGRect(x: 0, y: 0, width: item.size, height: item.size))
    
    if let resizedCG = resizeContext.makeImage() {
        let rep = NSBitmapImageRep(cgImage: resizedCG)
        if let png = rep.representation(using: .png, properties: [:]) {
            let outPath = "\(iconsetDir)/\(item.name)"
            try! png.write(to: URL(fileURLWithPath: outPath))
        }
    }
}

print("Iconset generated successfully.")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir, "-o", "\(rootDir)/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    print("Error: iconutil failed")
    exit(iconutil.terminationStatus)
}
print("Saved AppIcon.icns without an additional system frame.")
