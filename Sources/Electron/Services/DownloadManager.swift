import Foundation
import Combine

enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)
}

/// Handles fetching wallpaper media to disk, deduplicating in-flight
/// downloads, and evicting old files once the configured cache limit is
/// exceeded (simple least-recently-used-by-modification-date eviction).
@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var states: [String: DownloadState] = [:]

    private var session: URLSession!
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var progressObservations: [String: NSKeyValueObservation] = [:]
    private var wallpaperForTaskID: [Int: String] = [:]
    private var destinationFileNameForID: [String: String] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        refreshStatesFromDisk()
    }

    func localFileURL(for wallpaper: Wallpaper) -> URL {
        FileStorage.wallpapersDirectory().appendingPathComponent(wallpaper.localFileName)
    }

    func isDownloaded(_ wallpaper: Wallpaper) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: wallpaper).path)
    }

    func state(for wallpaper: Wallpaper) -> DownloadState {
        if let state = states[wallpaper.id] { return state }
        return isDownloaded(wallpaper) ? .downloaded : .notDownloaded
    }

    func download(_ wallpaper: Wallpaper) {
        guard tasks[wallpaper.id] == nil else { return }
        if isDownloaded(wallpaper) {
            states[wallpaper.id] = .downloaded
            return
        }
        states[wallpaper.id] = .downloading(progress: 0)
        let task = session.downloadTask(with: wallpaper.mediaURL)
        wallpaperForTaskID[task.taskIdentifier] = wallpaper.id
        destinationFileNameForID[wallpaper.id] = wallpaper.localFileName
        tasks[wallpaper.id] = task

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.states[wallpaper.id] = .downloading(progress: progress.fractionCompleted)
            }
        }
        progressObservations[wallpaper.id] = observation
        task.resume()
    }

    func cancel(_ wallpaper: Wallpaper) {
        tasks[wallpaper.id]?.cancel()
        tasks[wallpaper.id] = nil
        states[wallpaper.id] = .notDownloaded
    }

    func delete(_ wallpaper: Wallpaper) {
        try? FileManager.default.removeItem(at: localFileURL(for: wallpaper))
        states[wallpaper.id] = .notDownloaded
    }

    /// Removes oldest files until total size is under the configured limit.
    func enforceCacheLimit() {
        let limit = SettingsStore.shared.maxCacheBytes
        let dir = FileStorage.wallpapersDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        var entries = files.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate, let size = values.fileSize else { return nil }
            return (url, date, size)
        }
        entries.sort { $0.1 < $1.1 } // oldest first

        var total = entries.reduce(0) { $0 + $1.2 }
        for entry in entries {
            guard Int64(total) > limit else { break }
            try? FileManager.default.removeItem(at: entry.0)
            total -= entry.2
        }
    }

    private func refreshStatesFromDisk() {
        // Lazily resolved via `state(for:)`; nothing to precompute.
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let response = downloadTask.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            Task { @MainActor in
                let id = self.wallpaperForTaskID[downloadTask.taskIdentifier]
                if let id { self.states[id] = .failed("Server returned an error") }
            }
            return
        }
        // Move synchronously off the main actor since `location` is deleted
        // as soon as this delegate method returns.
        Task { @MainActor in
            guard let id = self.wallpaperForTaskID[downloadTask.taskIdentifier] else { return }
            defer {
                self.tasks[id] = nil
                self.progressObservations[id] = nil
                self.wallpaperForTaskID[downloadTask.taskIdentifier] = nil
                self.destinationFileNameForID[id] = nil
            }
            let fileName = self.destinationFileNameForID[id] ?? "\(id).mp4"
            let destination = FileStorage.wallpapersDirectory().appendingPathComponent(fileName)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
                self.states[id] = .downloaded
                self.enforceCacheLimit()
            } catch {
                self.states[id] = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor in
            if let id = self.wallpaperForTaskID[task.taskIdentifier] {
                self.states[id] = .failed(error.localizedDescription)
                self.tasks[id] = nil
            }
        }
    }
}
