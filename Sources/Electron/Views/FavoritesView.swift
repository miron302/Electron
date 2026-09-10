import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16)]

    var body: some View {
        Group {
            if favorites.favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites Yet",
                    systemImage: "heart",
                    description: Text("Tap the heart on any wallpaper to save it here.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(favorites.favorites) { wallpaper in
                            WallpaperCardView(wallpaper: wallpaper)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Favorites")
    }
}
