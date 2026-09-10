import Foundation

/// Wraps the public Pixabay Video API (https://pixabay.com/api/docs/#api_search_videos).
/// Content is distributed under the Pixabay Content License — free for
/// commercial and non-commercial use, no attribution legally required. We
/// still show the uploader's name and a link back.
final class PixabayProvider: WallpaperProvider {
    let id = "pixabay"
    let displayName = "Pixabay"

    private let session: URLSession
    private var apiKey: String? { SettingsStore.shared.pixabayAPIKey }

    var isConfigured: Bool { !(apiKey?.isEmpty ?? true) }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCurated(page: Int, perPage: Int) async throws -> [Wallpaper] {
        try await request(query: nil, page: page, perPage: perPage)
    }

    func search(query: String, page: Int, perPage: Int) async throws -> [Wallpaper] {
        try await request(query: query, page: page, perPage: perPage)
    }

    private func request(query: String?, page: Int, perPage: Int) async throws -> [Wallpaper] {
        guard let key = apiKey, !key.isEmpty else {
            throw ProviderError.missingAPIKey(providerName: displayName)
        }
        var components = URLComponents(string: "https://pixabay.com/api/videos/")!
        var items = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(max(perPage, 3))),
            URLQueryItem(name: "safesearch", value: "true"),
            URLQueryItem(name: "order", value: query == nil ? "popular" : "latest")
        ]
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        components.queryItems = items

        guard let url = components.url else { throw ProviderError.emptyResult }

        let data: Data
        do {
            let (responseData, _) = try await session.data(from: url)
            data = responseData
        } catch {
            throw ProviderError.network(underlying: error)
        }

        do {
            let decoded = try JSONDecoder().decode(PixabayResponse.self, from: data)
            return decoded.hits.compactMap(mapHit)
        } catch {
            throw ProviderError.decoding(underlying: error)
        }
    }

    private func mapHit(_ hit: PixabayHit) -> Wallpaper? {
        // Prefer "large" for quality vs. file-size balance; fall back down
        // the chain if it's missing.
        let variant = hit.videos.large ?? hit.videos.medium ?? hit.videos.small
        guard let variant, let mediaURL = URL(string: variant.url),
              let pageURL = URL(string: hit.pageURL) else { return nil }

        let previewURLString = "https://i.vimeocdn.com/video/\(hit.pictureId)_640x360.jpg"
        let previewURL = URL(string: previewURLString) ?? pageURL

        return Wallpaper(
            id: "pixabay-\(hit.id)",
            title: hit.tags.split(separator: ",").first.map(String.init) ?? "Pixabay wallpaper",
            providerID: id,
            providerDisplayName: displayName,
            sourcePageURL: pageURL,
            author: hit.user,
            authorPageURL: URL(string: "https://pixabay.com/users/\(hit.user)-\(hit.userID)/"),
            licenseSummary: "Free to use — Pixabay Content License",
            previewImageURL: previewURL,
            mediaURL: mediaURL,
            mediaType: .video,
            width: variant.width,
            height: variant.height,
            durationSeconds: Double(hit.duration),
            tags: hit.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            category: .all
        )
    }
}

// MARK: - Pixabay API response models

private struct PixabayResponse: Decodable {
    let hits: [PixabayHit]
}

private struct PixabayHit: Decodable {
    let id: Int
    let pageURL: String
    let tags: String
    let duration: Int
    let pictureId: String
    let user: String
    let userID: Int
    let videos: PixabayVideoVariants

    enum CodingKeys: String, CodingKey {
        case id, tags, duration, user, videos
        case pageURL = "pageURL"
        case pictureId = "picture_id"
        case userID = "user_id"
    }
}

private struct PixabayVideoVariants: Decodable {
    let large: PixabayVideoFile?
    let medium: PixabayVideoFile?
    let small: PixabayVideoFile?
}

private struct PixabayVideoFile: Decodable {
    let url: String
    let width: Int
    let height: Int
}
