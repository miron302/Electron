import SwiftUI

enum SidebarSection: Hashable {
    case category(WallpaperCategory)
    case favorites
}

struct ContentView: View {
    @EnvironmentObject private var gallery: GalleryViewModel
    @State private var selection: SidebarSection? = .category(.all)

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            Group {
                switch selection {
                case .favorites:
                    FavoritesView()
                case .category(let category):
                    GalleryView(category: category)
                case .none:
                    GalleryView(category: .all)
                }
            }
        }
        .navigationTitle("Electron")
        .sheet(isPresented: $gallery.isPreviewPresented) {
            if let wallpaper = gallery.selectedWallpaper {
                PreviewView(wallpaper: wallpaper)
            }
        }
    }
}
