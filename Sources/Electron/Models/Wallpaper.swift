import Foundation

/// The media type a wallpaper is delivered as. Kept separate from file
/// extension so the rendering engine can pick the right playback strategy.
enum WallpaperMediaType: String, Codable {
    case video
    case animatedGIF
}

/// A single wallpaper item, normalized from whichever provider produced it.
/// All providers map their native API response into this struct so the rest
/// of the app never needs to know where a wallpaper came from.
struct Wallpaper: Identifiable, Codable, Hashable {
    /// Namespaced so ids never collide across providers, e.g. "pexels-12345".
    let id: String
    let title: String
    let providerID: String
    let providerDisplayName: String
    let sourcePageURL: URL
    let author: String?
    let authorPageURL: URL?
    /// Human-readable license/usage summary shown in the UI, e.g.
    /// "Free to use — Pexels License".
    let licenseSummary: String
    let previewImageURL: URL
    let mediaURL: URL
    let mediaType: WallpaperMediaType
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let tags: [String]
    let category: WallpaperCategory

    var isAnimatedImage: Bool { mediaType == .animatedGIF }

    var aspectRatio: Double {
        guard height > 0 else { return 16.0 / 9.0 }
        return Double(width) / Double(height)
    }

    var localFileName: String {
        let ext = mediaType == .video ? "mp4" : "gif"
        return "\(id).\(ext)"
    }
}
