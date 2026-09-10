import Foundation
import Combine

/// Persists the full metadata of favorited wallpapers (not just ids) so the
/// Favorites tab still works offline and after app relaunch, even before a
/// fresh network fetch completes.
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var favorites: [Wallpaper] = []

    private let fileURL: URL
    private let settings = SettingsStore.shared

    init(fileManager: FileManager = .default) {
        let supportDir = FileStorage.applicationSupportDirectory()
        fileURL = supportDir.appendingPathComponent("favorites.json")
        load()
    }

    func isFavorite(_ wallpaper: Wallpaper) -> Bool {
        settings.favoriteIDs.contains(wallpaper.id)
    }

    func toggle(_ wallpaper: Wallpaper) {
        var ids = settings.favoriteIDs
        if ids.contains(wallpaper.id) {
            ids.remove(wallpaper.id)
            favorites.removeAll { $0.id == wallpaper.id }
        } else {
            ids.insert(wallpaper.id)
            favorites.append(wallpaper)
        }
        settings.favoriteIDs = ids
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Wallpaper].self, from: data) else { return }
        // Keep only wallpapers whose id is still marked as a favorite, in
        // case the two got out of sync.
        let ids = settings.favoriteIDs
        favorites = decoded.filter { ids.contains($0.id) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Small helper for consistent on-disk locations across the app.
enum FileStorage {
    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Electron", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func wallpapersDirectory() -> URL {
        let dir = applicationSupportDirectory().appendingPathComponent("Wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
