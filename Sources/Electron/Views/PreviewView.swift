import SwiftUI
import AVKit

struct PreviewView: View {
    let wallpaper: Wallpaper
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gallery: GalleryViewModel
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var settings = SettingsStore.shared

    @State private var player: AVPlayer?
    @State private var isMuted: Bool
    @State private var isLooping: Bool

    init(wallpaper: Wallpaper) {
        self.wallpaper = wallpaper
        _isMuted = State(initialValue: SettingsStore.shared.isMuted)
        _isLooping = State(initialValue: SettingsStore.shared.isLooping)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            playerArea
            controls
            footer
        }
        .frame(width: 760, height: 560)
        .onAppear(perform: setUpPlayer)
        .onDisappear { player?.pause() }
    }

    private var header: some View {
        HStack {
            Text(wallpaper.title)
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    @ViewBuilder
    private var playerArea: some View {
        if wallpaper.isAnimatedImage {
            AsyncImage(url: wallpaper.mediaURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        } else if let player {
            VideoPlayer(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else {
            ProgressView("Loading preview…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            if !wallpaper.isAnimatedImage {
                Toggle(isOn: $isMuted) { Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") }
                    .toggleStyle(.button)
                    .onChange(of: isMuted) { _, value in player?.isMuted = value }

                Toggle(isOn: $isLooping) { Image(systemName: "repeat") }
                    .toggleStyle(.button)
                    .onChange(of: isLooping) { _, value in settings.isLooping = value }
            }

            Spacer()

            favoriteButton
            downloadButton

            Button {
                gallery.apply(wallpaper)
                dismiss()
            } label: {
                Label("Apply Wallpaper", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let author = wallpaper.author {
                    Link(author, destination: wallpaper.authorPageURL ?? wallpaper.sourcePageURL)
                        .font(.caption)
                }
                Text(wallpaper.licenseSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Link("View on \(wallpaper.providerDisplayName)", destination: wallpaper.sourcePageURL)
                .font(.caption)
        }
        .padding()
        .background(.thinMaterial)
    }

    private var favoriteButton: some View {
        Button {
            favorites.toggle(wallpaper)
        } label: {
            Image(systemName: favorites.isFavorite(wallpaper) ? "heart.fill" : "heart")
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        switch downloadManager.state(for: wallpaper) {
        case .notDownloaded, .failed:
            Button { downloadManager.download(wallpaper) } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
        case .downloading(let progress):
            ProgressView(value: progress).frame(width: 80)
        case .downloaded:
            Label("Downloaded", systemImage: "checkmark.circle").foregroundStyle(.green)
        }
    }

    private func setUpPlayer() {
        guard !wallpaper.isAnimatedImage else { return }
        let localURL = downloadManager.localFileURL(for: wallpaper)
        let url = FileManager.default.fileExists(atPath: localURL.path) ? localURL : wallpaper.mediaURL
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = isMuted
        avPlayer.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: .main
        ) { _ in
            if isLooping {
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }
        }
        player = avPlayer
    }
}
