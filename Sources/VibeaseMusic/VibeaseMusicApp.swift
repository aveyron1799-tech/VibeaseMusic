import SwiftUI

@main
struct VibeaseMusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var player = PlayerService.shared
    @State private var account = AccountStore.shared
    @State private var settings = SettingsManager.shared
    @State private var toasts = ToastCenter.shared

    var body: some Scene {
        Window("VibeaseMusic", id: "main") {
            MainWindow()
                .environment(player)
                .environment(account)
                .environment(settings)
                .environment(toasts)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
                .frame(minWidth: Theme.Layout.minWindowWidth,
                       minHeight: Theme.Layout.minWindowHeight)
        }
        .defaultSize(width: Theme.Layout.defaultWindowWidth,
                     height: Theme.Layout.defaultWindowHeight)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("显示主窗口") {
                    WindowManager.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton()
            }

            CommandMenu("播放") {
                Button(player.isPlaying ? String(localized: "暂停") : String(localized: "播放")) {
                    player.togglePlayPause()
                }
                .disabled(!player.hasCurrentTrack)

                Button("下一首") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("上一首") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("随机播放") { player.toggleShuffle() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("循环模式") { player.cycleRepeatMode() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button(player.currentTrack.map { AccountStore.shared.isLiked($0.id) ? String(localized: "取消喜欢") : String(localized: "喜欢") } ?? String(localized: "喜欢")) {
                    if let track = player.currentTrack {
                        Task { await account.toggleLike(trackID: track.id) }
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(!player.hasCurrentTrack)

                Button("歌词") {
                    player.activePanel = player.activePanel == .lyrics ? nil : .lyrics
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("播放队列") {
                    player.activePanel = player.activePanel == .queue ? nil : .queue
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarPlayerView()
                .environment(player)
                .environment(account)
                .environment(settings)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
        } label: {
            MenuBarStatusLabel()
                .environment(player)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(account)
                .environment(settings)
                .tint(Theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    private var spaceIsDown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Refresh the running Dock tile from this bundle, bypassing stale icon caches.
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let iconURL = Bundle.main.url(forResource: iconName, withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        // Space toggles play/pause unless a text field is being edited.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            let noModifiers = event.modifierFlags
                .intersection([.command, .option, .control, .shift]).isEmpty
            let editingText = NSApp.keyWindow?.firstResponder is NSText
                || NSApp.keyWindow?.firstResponder is NSTextView

            if event.keyCode == 49 {
                if event.type == .keyUp {
                    self?.spaceIsDown = false
                    if noModifiers, !editingText { return nil }
                } else if noModifiers, !editingText {
                    // Consume repeats as well as the initial keyDown. Some
                    // macOS input sources do not reliably set isARepeat.
                    guard self?.spaceIsDown == false else { return nil }
                    self?.spaceIsDown = true
                    Task { @MainActor in
                        PlayerService.shared.togglePlayPause()
                    }
                    return nil
                }
            }
            // Esc: close the immersive now-playing page
            if event.type == .keyDown, event.keyCode == 53, noModifiers,
               MainActor.assumeIsolated({ PlayerService.shared.showNowPlaying }) {
                Task { @MainActor in
                    PlayerService.shared.showNowPlaying = false
                }
                return nil
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PlayerService.shared.flushPendingStateWrites()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.showMainWindow()
        }
        return true
    }
}
