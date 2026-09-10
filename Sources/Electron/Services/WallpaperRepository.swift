import Foundation

/// Fan-out point over every registered `WallpaperProvider`. The gallery
/// view model talks only to this type, so adding a third, fourth, fifth
/// provider never touches UI code — just register it in `Providers.all`.
enum Providers {
    static let pexels = PexelsProvider()
    static let pixabay = PixabayProvider()
    static let all: [WallpaperProvider] = [pexels, pixabay]
}

struct WallpaperRepository {
    var providers: [WallpaperProvider] = Providers.all

    var configuredProviders: [WallpaperProvider] { providers.filter { $0.isConfigured } }

    /// Fetches curated (non-search) results from every configured provider
    /// and interleaves them so the gallery isn't dominated by a single
    /// source when several are enabled.
    func fetchCurated(page: Int, category: WallpaperCategory) async -> Result<[Wallpaper], ProviderError> {
        let active = configuredProviders
        guard !active.isEmpty else {
            return .failure(.missingAPIKey(providerName: "Pexels or Pixabay"))
        }

        var results: [[Wallpaper]] = []
        var lastError: ProviderError?

        await withTaskGroup(of: (Int, [Wallpaper]).self) { group in
            for (index, provider) in active.enumerated() {
                group.addTask {
                    do {
                        let items: [Wallpaper]
                        if let term = category.searchTerm {
                            items = try await provider.search(query: term, page: page)
                        } else {
                            items = try await provider.fetchCurated(page: page)
                        }
                        return (index, items.map { withCategory(category, applyingTo: $0) })
                    } catch {
                        return (index, [])
                    }
                }
            }
            var ordered = Array(repeating: [Wallpaper](), count: active.count)
            for await (index, items) in group {
                ordered[index] = items
            }
            results = ordered
        }

        let interleaved = interleave(results)
        if interleaved.isEmpty {
            return .failure(lastError ?? .emptyResult)
        }
        return .success(interleaved)
    }

    func search(query: String, page: Int) async -> Result<[Wallpaper], ProviderError> {
        let active = configuredProviders
        guard !active.isEmpty else {
            return .failure(.missingAPIKey(providerName: "Pexels or Pixabay"))
        }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .success([])
        }

        var results: [[Wallpaper]] = []
        await withTaskGroup(of: (Int, [Wallpaper]).self) { group in
            for (index, provider) in active.enumerated() {
                group.addTask {
                    let items = (try? await provider.search(query: query, page: page)) ?? []
                    return (index, items)
                }
            }
            var ordered = Array(repeating: [Wallpaper](), count: active.count)
            for await (index, items) in group {
                ordered[index] = items
            }
            results = ordered
        }

        let interleaved = interleave(results)
        return interleaved.isEmpty ? .failure(.emptyResult) : .success(interleaved)
    }

    private func interleave(_ groups: [[Wallpaper]]) -> [Wallpaper] {
        var result: [Wallpaper] = []
        var indices = Array(repeating: 0, count: groups.count)
        var didAddAny = true
        while didAddAny {
            didAddAny = false
            for g in groups.indices {
                if indices[g] < groups[g].count {
                    result.append(groups[g][indices[g]])
                    indices[g] += 1
                    didAddAny = true
                }
            }
        }
        return result
    }

    private func withCategory(_ category: WallpaperCategory, applyingTo wallpaper: Wallpaper) -> Wallpaper {
        guard category != .all else { return wallpaper }
        return Wallpaper(
            id: wallpaper.id, title: wallpaper.title, providerID: wallpaper.providerID,
            providerDisplayName: wallpaper.providerDisplayName, sourcePageURL: wallpaper.sourcePageURL,
            author: wallpaper.author, authorPageURL: wallpaper.authorPageURL,
            licenseSummary: wallpaper.licenseSummary, previewImageURL: wallpaper.previewImageURL,
            mediaURL: wallpaper.mediaURL, mediaType: wallpaper.mediaType,
            width: wallpaper.width, height: wallpaper.height, durationSeconds: wallpaper.durationSeconds,
            tags: wallpaper.tags, category: category
        )
    }
}
