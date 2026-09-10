import SwiftUI

@main
struct ElectronApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var galleryViewModel = GalleryViewModel()
    @StateObject private var favoritesStore = FavoritesStore.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var engine = WallpaperEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(galleryViewModel)
                .environmentObject(favoritesStore)
                .environmentObject(settings)
                .environmentObject(engine)
                .frame(minWidth: 1000, minHeight: 680)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Electron", systemImage: "sparkles.tv") {
            MenuBarView()
                .environmentObject(engine)
                .environmentObject(favoritesStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(engine)
                .frame(width: 520, height: 460)
        }
    }
}
