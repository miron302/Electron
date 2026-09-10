import Foundation

/// Wraps the public Pexels Video API (https://www.pexels.com/api/documentation/#videos-overview).
/// Every video on Pexels is distributed under the Pexels License, which
/// permits free use for wallpapers without attribution — we still surface
/// the photographer's name and a link back for courtesy and to satisfy the
/// "clearly display source/license" requirement.
final class PexelsProvider: WallpaperProvider {
    let id = "pexels"
    let displayName = "Pexels"

    private let session: URLSession
    private var apiKey: String? { SettingsStore.shared.pexelsAPIKey }

    var isConfigured: Bool { !(apiKey?.isEmpty ?? true) }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCurated(page: Int, perPage: Int) async throws -> [Wallpaper] {
        var components = URLComponents(string: "https://api.pexels.com/videos/popular")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        return try await request(components)
    }

    func search(query: String, page: Int, perPage: Int) async throws -> [Wallpaper] {
        var components = URLComponents(string: "https://api.pexels.com/videos/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        return try await request(components)
    }

    private func request(_ components: URLComponents) async throws -> [Wallpaper] {
        guard let key = apiKey, !key.isEmpty else {
            throw ProviderError.missingAPIKey(providerName: displayName)
        }
        guard let url = components.url else { throw ProviderError.emptyResult }

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Authorization")

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw ProviderError.network(underlying: error)
        }

        do {
            let decoded = try JSONDecoder().decode(PexelsVideoResponse.self, from: data)
            return decoded.videos.compactMap(mapVideo)
        } catch {
            throw ProviderError.decoding(underlying: error)
        }
    }

    private func mapVideo(_ video: PexelsVideo) -> Wallpaper? {
        // Prefer an HD file capped around 1080p so downloads/playback stay
        // reasonably light; fall back to the largest available otherwise.
        let candidates = video.videoFiles.filter { $0.fileType == "video/mp4" }
        let hdFile = candidates
            .filter { ($0.width ?? 0) <= 1920 }
            .sorted { ($0.width ?? 0) > ($1.width ?? 0) }
            .first
        guard let file = hdFile ?? candidates.sorted(by: { ($0.width ?? 0) > ($1.width ?? 0) }).first,
              let fileURL = URL(string: file.link),
              let previewURL = URL(string: video.image),
              let pageURL = URL(string: video.url) else {
            return nil
        }

        return Wallpaper(
            id: "pexels-\(video.id)",
            title: "Video by \(video.user.name)",
            providerID: id,
            providerDisplayName: displayName,
            sourcePageURL: pageURL,
            author: video.user.name,
            authorPageURL: URL(string: video.user.url),
            licenseSummary: "Free to use — Pexels License",
            previewImageURL: previewURL,
            mediaURL: fileURL,
            mediaType: .video,
            width: file.width ?? video.width,
            height: file.height ?? video.height,
            durationSeconds: video.duration,
            tags: [],
            category: .all
        )
    }
}

// MARK: - Pexels API response models

private struct PexelsVideoResponse: Decodable {
    let videos: [PexelsVideo]
}

private struct PexelsVideo: Decodable {
    let id: Int
    let width: Int
    let height: Int
    let url: String
    let image: String
    let duration: Double?
    let user: PexelsUser
    let videoFiles: [PexelsVideoFile]

    enum CodingKeys: String, CodingKey {
        case id, width, height, url, image, duration, user
        case videoFiles = "video_files"
    }
}

private struct PexelsUser: Decodable {
    let name: String
    let url: String
}

private struct PexelsVideoFile: Decodable {
    let link: String
    let fileType: String
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case link, width, height
        case fileType = "file_type"
    }
}
