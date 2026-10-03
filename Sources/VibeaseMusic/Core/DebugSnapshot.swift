#if DEBUG
import AppKit

/// Debug-only self capture for visual review without Screen Recording access.
/// Launch with `open --env VIBEASE_SNAPSHOT_DIR=/path App.app`.
enum DebugSnapshot {
    @MainActor
    static func scheduleIfRequested() {
        let env = ProcessInfo.processInfo.environment
        if env["VIBEASE_TOUR"] != nil {
            runTour()
            return
        }
        guard let dir = env["VIBEASE_SNAPSHOT_DIR"] else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(9))
            capture(to: "\(dir)/home.png")
            if PlayerService.shared.hasCurrentTrack {
                PlayerService.shared.activePanel = .queue
                try? await Task.sleep(for: .seconds(2))
                capture(to: "\(dir)/queue.png")
                PlayerService.shared.activePanel = nil
                PlayerService.shared.showNowPlaying = true
                try? await Task.sleep(for: .seconds(4))
                capture(to: "\(dir)/nowplaying.png")
                PlayerService.shared.showNowPlaying = false
            }
        }
    }

    /// Steps through key states on a fixed schedule so an external
    /// `screencapture` can grab each one: 10s queue, 14s lyrics panel,
    /// 18s now playing, 26s back to home.
    @MainActor
    private static func runTour() {
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(for: .seconds(10))
            PlayerService.shared.activePanel = .queue
            try? await Task.sleep(for: .seconds(4))
            PlayerService.shared.activePanel = .lyrics
            try? await Task.sleep(for: .seconds(4))
            PlayerService.shared.activePanel = nil
            PlayerService.shared.showNowPlaying = true
            try? await Task.sleep(for: .seconds(8))
            PlayerService.shared.showNowPlaying = false
        }
    }

    @MainActor
    static func capture(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.width > 600 }),
              let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
#endif
