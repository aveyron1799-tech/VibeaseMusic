import AppKit
import SwiftUI

// MARK: - Window Manager

@MainActor
public final class WindowManager: NSObject {
    public static let shared = WindowManager()

    public weak var mainWindow: NSWindow?

    /// Brings the main window to front and activates the application.
    public static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = shared.mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            for window in NSApp.windows where !(window is NSPanel) && window.canBecomeMain {
                shared.mainWindow = window
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                break
            }
        }
    }

    /// Hides the main window (music continues in background).
    public static func hideMainWindow() {
        if let window = shared.mainWindow {
            window.orderOut(nil)
        } else {
            for window in NSApp.windows where !(window is NSPanel) && window.canBecomeMain {
                window.orderOut(nil)
            }
        }
    }

    /// Toggles the main window visibility.
    public static func toggleMainWindow() {
        if let window = shared.mainWindow, window.isVisible && window.isKeyWindow {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }
}

// MARK: - Main Window Delegate

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Intercept close button / Cmd+W and hide instead of deallocating the window
        sender.orderOut(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        // Fallback safety
        if let window = notification.object as? NSWindow, window == WindowManager.shared.mainWindow {
            WindowManager.shared.mainWindow = nil
        }
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window: window)
            }
        }
    }

    private func suppressSidebarFocusRing(in view: NSView) {
        view.focusRingType = .none
        for child in view.subviews {
            suppressSidebarFocusRing(in: child)
        }
    }

    private func configure(window: NSWindow) {
        if WindowManager.shared.mainWindow !== window {
            WindowManager.shared.mainWindow = window
            window.delegate = MainWindowDelegate.shared
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = false
            // The sidebar is a plain scroll view, so AppKit would hand initial
            // keyboard focus to the first toolbar button and ring it.
            window.initialFirstResponder = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak window] in
                guard let window, !(window.firstResponder is NSText) else { return }
                window.makeFirstResponder(nil)
            }
        }
        // Keep the system sidebar item, including its placement and keyboard action.
        // Suppress only this item's blue focus ring, not focus throughout the window.
        for item in window.toolbar?.items ?? [] where
            item.itemIdentifier == .toggleSidebar ||
            item.itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar" {
            if let view = item.view {
                suppressSidebarFocusRing(in: view)
            }
        }
        onWindow(window)
    }
}


