import AppKit
import CryptoKit
import SwiftUI

/// Two-tier (memory + disk) image cache with in-flight request coalescing.
actor ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, NSImage>()
    private let diskURL: URL
    private var inflight: [String: Task<NSImage?, Never>] = [:]

    private static let diskLimitBytes = 300 * 1024 * 1024

    private static var diskDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.vibease.music/images", isDirectory: true)
    }

    private init() {
        memory.countLimit = 300
        memory.totalCostLimit = 64 * 1024 * 1024
        diskURL = Self.diskDirectory
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    /// Trims the disk tier to `diskLimitBytes`, evicting least recently used files
    /// first (disk hits refresh the modification date).
    nonisolated static func pruneDiskCacheInBackground() {
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey, .isRegularFileKey]
            guard let files = try? fm.contentsOfDirectory(
                at: diskDirectory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
            ) else { return }
            var entries: [(url: URL, date: Date, size: Int)] = []
            var total = 0
            for file in files {
                guard let values = try? file.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                let size = values.totalFileAllocatedSize ?? 0
                total += size
                entries.append((file, values.contentModificationDate ?? .distantPast, size))
            }
            guard total > diskLimitBytes else { return }
            for entry in entries.sorted(by: { $0.date < $1.date }) {
                guard total > diskLimitBytes else { break }
                if (try? fm.removeItem(at: entry.url)) != nil { total -= entry.size }
            }
        }
    }

    func image(for url: URL) async -> NSImage? {
        let key = Self.cacheKey(for: url)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }
        if let existing = inflight[key] {
            return await existing.value
        }
        let task = Task<NSImage?, Never> { [diskURL] in
            let fileURL = diskURL.appendingPathComponent(key)
            if let data = try? Data(contentsOf: fileURL), let image = NSImage(data: data) {
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                return image
            }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let image = NSImage(data: data) else { return nil }
            try? data.write(to: fileURL, options: .atomic)
            return image
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        if let result {
            memory.setObject(result, forKey: key as NSString,
                             cost: Int(result.size.width * result.size.height * 4))
        }
        return result
    }

    private static func cacheKey(for url: URL) -> String {
        let digest = Insecure.MD5.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension NSImage {
    /// Renders the image into a circle of the given point diameter.
    /// Useful where SwiftUI clipping is unreliable (menu labels, NSMenu items).
    func circularCropped(diameter: CGFloat) -> NSImage {
        let target = NSImage(size: NSSize(width: diameter, height: diameter))
        target.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: diameter, height: diameter)
        NSBezierPath(ovalIn: rect).addClip()
        // Aspect-fill the source into the circle.
        let sourceAspect = size.width / max(size.height, 1)
        var drawRect = rect
        if sourceAspect > 1 {
            drawRect.size.width = diameter * sourceAspect
            drawRect.origin.x = -(drawRect.width - diameter) / 2
        } else if sourceAspect < 1 {
            drawRect.size.height = diameter / sourceAspect
            drawRect.origin.y = -(drawRect.height - diameter) / 2
        }
        draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
        target.unlockFocus()
        return target
    }
}

/// AsyncImage replacement backed by `ImageCache`, with a crossfade reveal.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    var animated: Bool = true
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: NSImage?
    @State private var loadedURL: URL?

    var body: some View {
        ZStack {
            placeholder()
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(animated ? .opacity.animation(.easeIn(duration: 0.22)) : .identity)
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                loadedURL = nil
                return
            }
            guard url != loadedURL else { return }
            let loaded = await ImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            // A failed load must clear the previous URL's image rather than keep showing it.
            image = loaded
            loadedURL = loaded == nil ? nil : url
        }
    }
}

extension CachedAsyncImage where Placeholder == AnyView {
    /// Default placeholder: a quiet neutral fill with a music note.
    init(url: URL?, animated: Bool = true) {
        self.init(url: url, animated: animated) {
            AnyView(
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.5))
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.quaternary)
                }
            )
        }
    }
}
