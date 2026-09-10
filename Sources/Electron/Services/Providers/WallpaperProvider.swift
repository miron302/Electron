import Foundation

enum ProviderError: LocalizedError {
    case missingAPIKey(providerName: String)
    case network(underlying: Error)
    case decoding(underlying: Error)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let name):
            return "\(name) needs a free API key. Add one in Settings → Providers."
        case .network(let underlying):
            return "Couldn't reach the network: \(underlying.localizedDescription)"
        case .decoding:
            return "Received an unexpected response from the wallpaper provider."
        case .emptyResult:
            return "No wallpapers found."
        }
    }
}

/// Anything that can supply wallpapers implements this. Adding a new source
/// of wallpapers (a new stock-video site, a local folder, a self-hosted
/// server, etc.) only requires a new conformer — nothing else in the app
/// needs to change.
protocol WallpaperProvider {
    /// Stable machine identifier, used to namespace wallpaper ids.
    var id: String { get }
    /// Shown in the UI and in attribution strings.
    var displayName: String { get }
    /// Whether this provider currently has what it needs (e.g. an API key)
    /// to make requests.
    var isConfigured: Bool { get }

    func fetchCurated(page: Int, perPage: Int) async throws -> [Wallpaper]
    func search(query: String, page: Int, perPage: Int) async throws -> [Wallpaper]
}

extension WallpaperProvider {
    func fetchCurated(page: Int) async throws -> [Wallpaper] {
        try await fetchCurated(page: page, perPage: 30)
    }
    func search(query: String, page: Int) async throws -> [Wallpaper] {
        try await search(query: query, page: page, perPage: 30)
    }
}
