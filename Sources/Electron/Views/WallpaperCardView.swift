import SwiftUI

struct WallpaperCardView: View {
    let wallpaper: Wallpaper

    @EnvironmentObject private var gallery: GalleryViewModel
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
            metadata
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator, lineWidth: 0.5))
        .onHover { isHovering = $0 }
    }

    private var thumbnail: some View {
        ZStack {
            AsyncImage(url: wallpaper.previewImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle().fill(.quaternary).overlay(Image(systemName: "photo"))
                default:
                    Rectangle().fill(.quaternary)
                        .overlay(ProgressView())
                }
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isHovering {
                Color.black.opacity(0.35)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                actionButtons
            }

            VStack {
                HStack {
                    Spacer()
                    favoriteButton
                }
                Spacer()
            }
            .padding(6)
        }
        .frame(height: 150)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { gallery.openPreview(wallpaper) } label: {
                Image(systemName: "eye.fill")
            }
            .help("Preview")

            downloadButton

            Button { gallery.apply(wallpaper) } label: {
                Image(systemName: "checkmark.circle.fill")
            }
            .help("Apply as wallpaper")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.white.opacity(0.9))
        .foregroundStyle(.black)
    }

    @ViewBuilder
    private var downloadButton: some View {
        switch downloadManager.state(for: wallpaper) {
        case .notDownloaded:
            Button { downloadManager.download(wallpaper) } label: {
                Image(systemName: "arrow.down.circle.fill")
            }
            .help("Download")
        case .downloading(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .frame(width: 24, height: 24)
        case .downloaded:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
                .help("Downloaded")
        case .failed:
            Button { downloadManager.download(wallpaper) } label: {
                Image(systemName: "exclamationmark.arrow.circlepath")
            }
            .help("Download failed — tap to retry")
        }
    }

    private var favoriteButton: some View {
        Button {
            favorites.toggle(wallpaper)
        } label: {
            Image(systemName: favorites.isFavorite(wallpaper) ? "heart.fill" : "heart")
                .foregroundStyle(favorites.isFavorite(wallpaper) ? .red : .white)
                .padding(6)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wallpaper.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(wallpaper.providerDisplayName)
                Text("·")
                Text(wallpaper.licenseSummary)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}
