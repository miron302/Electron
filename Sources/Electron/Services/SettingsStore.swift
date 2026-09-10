import Foundation
import Combine

enum AutoChangeInterval: TimeInterval, CaseIterable, Identifiable {
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case threeHours = 10_800
    case daily = 86_400

    var id: RawValue { rawValue }

    var displayName: String {
        switch self {
        case .fifteenMinutes: return "Every 15 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour: return "Every hour"
        case .threeHours: return "Every 3 hours"
        case .daily: return "Once a day"
        }
    }
}

enum AutoChangeSource: String, CaseIterable, Identifiable {
    case favorites
    case downloaded
    case both

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .favorites: return "Favorites only"
        case .downloaded: return "Downloaded wallpapers"
        case .both: return "Favorites + downloaded"
        }
    }
}

/// Thin, observable wrapper around UserDefaults. Kept as a single source of
/// truth so both SwiftUI views and the background wallpaper engine read and
/// write the same values.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    private enum Keys {
        static let pexelsAPIKey = "pexelsAPIKey"
        static let pixabayAPIKey = "pixabayAPIKey"
        static let isMuted = "isMuted"
        static let isLooping = "isLooping"
        static let restoreOnLaunch = "restoreOnLaunch"
        static let lastWallpaperData = "lastWallpaperData"
        static let autoChangeEnabled = "autoChangeEnabled"
        static let autoChangeInterval = "autoChangeInterval"
        static let autoChangeSource = "autoChangeSource"
        static let pauseOnBattery = "pauseOnBattery"
        static let pauseWhenFullscreenAppActive = "pauseWhenFullscreenAppActive"
        static let launchAtLogin = "launchAtLogin"
        static let maxCacheBytes = "maxCacheBytes"
        static let favoriteIDs = "favoriteIDs"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.isMuted: true,
            Keys.isLooping: true,
            Keys.restoreOnLaunch: true,
            Keys.autoChangeEnabled: false,
            Keys.autoChangeInterval: AutoChangeInterval.oneHour.rawValue,
            Keys.autoChangeSource: AutoChangeSource.favorites.rawValue,
            Keys.pauseOnBattery: false,
            Keys.pauseWhenFullscreenAppActive: true,
            Keys.launchAtLogin: false,
            Keys.maxCacheBytes: 2_000_000_000 // 2 GB
        ])
    }

    // MARK: Provider API keys

    @Published var pexelsAPIKeyPublished: String = ""
    var pexelsAPIKey: String? {
        get { defaults.string(forKey: Keys.pexelsAPIKey) }
        set { defaults.set(newValue, forKey: Keys.pexelsAPIKey); pexelsAPIKeyPublished = newValue ?? "" }
    }

    var pixabayAPIKey: String? {
        get { defaults.string(forKey: Keys.pixabayAPIKey) }
        set { defaults.set(newValue, forKey: Keys.pixabayAPIKey) }
    }

    // MARK: Playback

    var isMuted: Bool {
        get { defaults.bool(forKey: Keys.isMuted) }
        set { defaults.set(newValue, forKey: Keys.isMuted) }
    }

    var isLooping: Bool {
        get { defaults.bool(forKey: Keys.isLooping) }
        set { defaults.set(newValue, forKey: Keys.isLooping) }
    }

    var restoreOnLaunch: Bool {
        get { defaults.bool(forKey: Keys.restoreOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.restoreOnLaunch) }
    }

    var lastWallpaperData: Data? {
        get { defaults.data(forKey: Keys.lastWallpaperData) }
        set { defaults.set(newValue, forKey: Keys.lastWallpaperData) }
    }

    // MARK: Auto-change

    var autoChangeEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoChangeEnabled) }
        set { defaults.set(newValue, forKey: Keys.autoChangeEnabled) }
    }

    var autoChangeInterval: AutoChangeInterval {
        get { AutoChangeInterval(rawValue: defaults.double(forKey: Keys.autoChangeInterval)) ?? .oneHour }
        set { defaults.set(newValue.rawValue, forKey: Keys.autoChangeInterval) }
    }

    var autoChangeSource: AutoChangeSource {
        get { AutoChangeSource(rawValue: defaults.string(forKey: Keys.autoChangeSource) ?? "") ?? .favorites }
        set { defaults.set(newValue.rawValue, forKey: Keys.autoChangeSource) }
    }

    // MARK: Performance

    var pauseOnBattery: Bool {
        get { defaults.bool(forKey: Keys.pauseOnBattery) }
        set { defaults.set(newValue, forKey: Keys.pauseOnBattery) }
    }

    var pauseWhenFullscreenAppActive: Bool {
        get { defaults.bool(forKey: Keys.pauseWhenFullscreenAppActive) }
        set { defaults.set(newValue, forKey: Keys.pauseWhenFullscreenAppActive) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    var maxCacheBytes: Int64 {
        get { Int64(defaults.integer(forKey: Keys.maxCacheBytes)) }
        set { defaults.set(Int(newValue), forKey: Keys.maxCacheBytes) }
    }

    // MARK: Favorites (ids only — full wallpaper metadata is cached separately)

    var favoriteIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.favoriteIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.favoriteIDs) }
    }
}
