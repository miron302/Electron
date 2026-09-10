import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection?
    @EnvironmentObject private var engine: WallpaperEngine

    var body: some View {
        List(selection: $selection) {
            Section("Browse") {
                ForEach(WallpaperCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbolName)
                        .tag(SidebarSection.category(category))
                }
            }
            Section("Library") {
                Label("Favorites", systemImage: "heart")
                    .tag(SidebarSection.favorites)
            }
            if let current = engine.currentWallpaper {
                Section("Now Playing") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.title)
                            .font(.caption)
                            .lineLimit(1)
                        HStack {
                            Button {
                                engine.togglePlayPause()
                            } label: {
                                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            }
                            .buttonStyle(.borderless)
                            Text(current.providerDisplayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}
