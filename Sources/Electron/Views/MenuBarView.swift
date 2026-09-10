import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var engine: WallpaperEngine
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let wallpaper = engine.currentWallpaper {
                Text(wallpaper.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("via \(wallpaper.providerDisplayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No wallpaper applied")
                    .font(.headline)
            }

            Divider()

            Button {
                engine.togglePlayPause()
            } label: {
                Label(engine.isPlaying ? "Pause" : "Resume", systemImage: engine.isPlaying ? "pause.fill" : "play.fill")
            }

            Button {
                if let next = favorites.favorites.randomElement() {
                    engine.apply(next)
                }
            } label: {
                Label("Random Favorite", systemImage: "shuffle")
            }
            .disabled(favorites.favorites.isEmpty)

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.title == "Electron" {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Open Electron", systemImage: "square.grid.2x2")
            }

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Electron", systemImage: "power")
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
