import SwiftUI
import AppKit

struct GalleryView: View {
    let category: WallpaperCategory
    @EnvironmentObject private var gallery: GalleryViewModel

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
        .onAppear {
            gallery.selectedCategory = category
            gallery.onAppear()
        }
        .onChange(of: category) { _, newValue in
            gallery.selectCategory(newValue)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search wallpapers…", text: $gallery.searchText)
                .textFieldStyle(.plain)
                .onChange(of: gallery.searchText) { _, _ in
                    gallery.searchTextChanged()
                }
            if !gallery.searchText.isEmpty {
                Button {
                    gallery.searchText = ""
                    gallery.searchTextChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        switch gallery.loadState {
        case .idle, 
                .loading where gallery.wallpapers.isEmpty:
            ProgressView("Loading wallpapers…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            ContentUnavailableView {
                Label("Couldn't load wallpapers", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await gallery.loadInitial() } }
                if message.contains("API key") {
                    // `showSettingsWindow:` is the AppKit action SwiftUI's
                    // `Settings` scene registers; sending it directly keeps
                    // this working back to macOS 13 (the `openSettings`
                    // environment action only exists from macOS 14).
                    SettingsLink {
                        Text("Open Settings")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(gallery.wallpapers) { wallpaper in
                        WallpaperCardView(wallpaper: wallpaper)
                            .onAppear {
                                if wallpaper.id == gallery.wallpapers.last?.id {
                                    Task { await gallery.loadMore() }
                                }
                            }
                    }
                }
                .padding(16)
            }
        }
    }
}
