import AppKit
import AVFoundation
import Combine

/// A borderless window pinned just above the desktop icons, behind every
/// normal app window, on every Space. This is the same trick used by other
/// live-wallpaper utilities: it never becomes key/main so it can't steal
/// focus or keyboard input.
private final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopWindow))
        )
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isOpaque = true
        self.backgroundColor = .black
        self.hasShadow = false
        self.ignoresMouseEvents = true
    }
}

/// Owns one player (or animated image view) per connected screen and keeps
/// them synchronized with user settings.
@MainActor
final class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine()

    @Published private(set) var currentWallpaper: Wallpaper?
    @Published private(set) var isPlaying = true

    private var windows: [ObjectIdentifier: WallpaperWindow] = [:]
    private var players: [ObjectIdentifier: AVQueuePlayer] = [:]
    private var loopers: [ObjectIdentifier: AVPlayerLooper] = [:]
    private var imageViews: [ObjectIdentifier: NSImageView] = [:]
    private var playerLayers: [ObjectIdentifier: AVPlayerLayer] = [:]

    private var autoChangeTimer: Timer?
    private var candidatePool: [Wallpaper] = []

    private init() {
        observeScreenChanges()
        observeSleepAndLock()
    }

    // MARK: - Lifecycle

    func restoreLastSession() {
        let settings = SettingsStore.shared

        if settings.restoreOnLaunch,
           let data = settings.lastWallpaperData,
           let wallpaper = try? JSONDecoder().decode(
               Wallpaper.self,
               from: data
           ) {
            apply(wallpaper)
        }

        if settings.autoChangeEnabled {
            startAutoChange()
        }
    }

    // MARK: - Applying wallpapers

    func apply(_ wallpaper: Wallpaper) {
        currentWallpaper = wallpaper

        SettingsStore.shared.lastWallpaperData =
            try? JSONEncoder().encode(wallpaper)

        let localURL = DownloadManager.shared.localFileURL(for: wallpaper)

        let sourceURL: URL
        if FileManager.default.fileExists(atPath: localURL.path) {
            sourceURL = localURL
        } else {
            sourceURL = wallpaper.mediaURL
        }

        for screen in NSScreen.screens {
            let window = windowForScreen(screen)

            switch wallpaper.mediaType {
            case .video:
                clearImageView(for: screen)
                playVideo(
                    url: sourceURL,
                    in: window,
                    for: screen
                )

            case .animatedGIF:
                clearPlayer(for: screen)
                showAnimatedImage(
                    url: sourceURL,
                    in: window,
                    for: screen
                )
            }

            window.orderFront(nil)
        }

        isPlaying = true
    }

    func stop() {
        for screen in NSScreen.screens {
            windows[ObjectIdentifier(screen)]?.orderOut(nil)
        }

        players.values.forEach { $0.pause() }

        currentWallpaper = nil
    }

    // MARK: - Playback controls

    func togglePlayPause() {
        isPlaying.toggle()

        if isPlaying {
            players.values.forEach { $0.play() }
            imageViews.values.forEach { $0.animates = true }
        } else {
            players.values.forEach { $0.pause() }
            imageViews.values.forEach { $0.animates = false }
        }
    }

    func setMuted(_ muted: Bool) {
        SettingsStore.shared.isMuted = muted

        players.values.forEach {
            $0.isMuted = muted
        }
    }

    func setLooping(_ looping: Bool) {
        SettingsStore.shared.isLooping = looping

        // AVPlayerLooper is configured when the video is applied.
        // Re-applying the wallpaper rebuilds the player with the new setting.
    }

    // MARK: - Auto-change

    func startAutoChange() {
        stopAutoChange()

        let interval = SettingsStore.shared.autoChangeInterval.rawValue

        autoChangeTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.advanceToNextWallpaper()
            }
        }
    }

    func stopAutoChange() {
        autoChangeTimer?.invalidate()
        autoChangeTimer = nil
    }

    func updateAutoChangeCandidates(_ wallpapers: [Wallpaper]) {
        candidatePool = wallpapers
    }

    private func advanceToNextWallpaper() {
        guard !candidatePool.isEmpty else {
            return
        }

        var next = candidatePool.randomElement()

        if candidatePool.count > 1 {
            while next?.id == currentWallpaper?.id {
                next = candidatePool.randomElement()
            }
        }

        if let next {
            apply(next)
        }
    }

    // MARK: - Per-screen window management

    private func windowForScreen(_ screen: NSScreen) -> WallpaperWindow {
        let key = ObjectIdentifier(screen)

        if let existing = windows[key] {
            existing.setFrame(
                screen.frame,
                display: true
            )

            return existing
        }

        let window = WallpaperWindow(screen: screen)

        windows[key] = window

        return window
    }

    // MARK: - Video playback

    private func playVideo(
        url: URL,
        in window: WallpaperWindow,
        for screen: NSScreen
    ) {
        let key = ObjectIdentifier(screen)

        // Clean up any previous player for this screen.
        clearPlayer(for: screen)

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()

        player.isMuted = SettingsStore.shared.isMuted

        if SettingsStore.shared.isLooping {
            let looper = AVPlayerLooper(
                player: player,
                templateItem: item
            )

            loopers[key] = looper
        } else {
            player.insert(
                item,
                after: nil
            )
        }

        let hostView = NSView(
            frame: NSRect(
                origin: .zero,
                size: screen.frame.size
            )
        )

        hostView.wantsLayer = true
        hostView.layer = CALayer()
        hostView.autoresizingMask = [
            .width,
            .height
        ]

        let playerLayer = AVPlayerLayer(
            player: player
        )

        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = hostView.bounds
        playerLayer.autoresizingMask = [
            .layerWidthSizable,
            .layerHeightSizable
        ]

        hostView.layer?.addSublayer(playerLayer)

        window.contentView = hostView

        players[key] = player
        playerLayers[key] = playerLayer

        if isPlaying {
            player.play()
        }
    }

    // MARK: - Animated images

    private func showAnimatedImage(
        url: URL,
        in window: WallpaperWindow,
        for screen: NSScreen
    ) {
        let key = ObjectIdentifier(screen)

        guard let image = NSImage(contentsOf: url) else {
            return
        }

        let imageView = NSImageView(
            frame: window.contentView?.bounds
                ?? screen.frame
        )

        imageView.image = image
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = isPlaying
        imageView.autoresizingMask = [
            .width,
            .height
        ]

        window.contentView = imageView

        imageViews[key] = imageView
    }

    // MARK: - Cleanup

    private func clearPlayer(for screen: NSScreen) {
        let key = ObjectIdentifier(screen)

        players[key]?.pause()
        players[key] = nil

        loopers[key] = nil
        playerLayers[key] = nil
    }

    private func clearImageView(for screen: NSScreen) {
        let key = ObjectIdentifier(screen)

        imageViews[key]?.animates = false
        imageViews[key] = nil
    }

    // MARK: - System observers

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      let wallpaper = self.currentWallpaper
                else {
                    return
                }

                self.apply(wallpaper)
            }
        }
    }

    private func observeSleepAndLock() {
        let workspaceCenter =
            NSWorkspace.shared.notificationCenter

        // Screens going to sleep.
        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.players.values.forEach {
                    $0.pause()
                }
            }
        }

        // Screens waking up.
        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      self.isPlaying
                else {
                    return
                }

                self.players.values.forEach {
                    $0.play()
                }
            }
        }

        // Screen locked.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(
                "com.apple.screenIsLocked"
            ),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.players.values.forEach {
                    $0.pause()
                }
            }
        }

        // Screen unlocked.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(
                "com.apple.screenIsUnlocked"
            ),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      self.isPlaying
                else {
                    return
                }

                self.players.values.forEach {
                    $0.play()
                }
            }
        }
    }
}
