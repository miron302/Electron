import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        WallpaperEngine.shared.restoreLastSession()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Electron keeps running so the desktop wallpaper (and menu bar
        // controls) stay alive even after the gallery window is closed.
        false
    }
}
