import Foundation
import Combine

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var wallpapers: [Wallpaper] = []
    @Published var loadState: LoadState = .idle
    @Published var searchText: String = ""
    @Published var selectedCategory: WallpaperCategory = .all
    @Published var selectedWallpaper: Wallpaper?
    @Published var isPreviewPresented = false

    private let repository = WallpaperRepository()
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?

    var hasConfiguredProvider: Bool { !repository.configuredProviders.isEmpty }

    func onAppear() {
        guard wallpapers.isEmpty else { return }
        Task { await loadInitial() }
    }

    func loadInitial() async {
        currentPage = 1
        loadState = .loading
        let result = searchText.isEmpty
            ? await repository.fetchCurated(page: currentPage, category: selectedCategory)
            : await repository.search(query: searchText, page: currentPage)

        switch result {
        case .success(let items):
            wallpapers = items
            loadState = .loaded
            WallpaperEngine.shared.updateAutoChangeCandidates(items)
        case .failure(let error):
            wallpapers = []
            loadState = .error(error.errorDescription ?? "Something went wrong.")
        }
    }

    func loadMore() async {
        guard loadState == .loaded else { return }
        currentPage += 1
        let result = searchText.isEmpty
            ? await repository.fetchCurated(page: currentPage, category: selectedCategory)
            : await repository.search(query: searchText, page: currentPage)

        if case .success(let items) = result {
            wallpapers.append(contentsOf: items)
        }
    }

    func selectCategory(_ category: WallpaperCategory) {
        guard category != selectedCategory else { return }
        selectedCategory = category
        Task { await loadInitial() }
    }

    /// Debounces search input so we don't fire a network request per
    /// keystroke.
    func searchTextChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await loadInitial()
        }
    }

    func openPreview(_ wallpaper: Wallpaper) {
        selectedWallpaper = wallpaper
        isPreviewPresented = true
    }

    func apply(_ wallpaper: Wallpaper) {
        WallpaperEngine.shared.apply(wallpaper)
    }
}
