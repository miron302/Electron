import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            ProvidersSettingsTab()
                .tabItem { Label("Providers", systemImage: "key") }
            PlaybackSettingsTab()
                .tabItem { Label("Playback", systemImage: "play.circle") }
            AutoChangeSettingsTab()
                .tabItem { Label("Auto-Change", systemImage: "clock.arrow.circlepath") }
            PerformanceSettingsTab()
                .tabItem { Label("Performance", systemImage: "bolt") }
            StorageSettingsTab()
                .tabItem { Label("Storage", systemImage: "internaldrive") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
    }
}

private struct ProvidersSettingsTab: View {
    @State private var pexelsKey = SettingsStore.shared.pexelsAPIKey ?? ""
    @State private var pixabayKey = SettingsStore.shared.pixabayAPIKey ?? ""

    var body: some View {
        Form {
            Section {
                Text("Electron pulls wallpapers from free stock-video providers. Each needs its own free API key — get one from the links below, then paste it here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Pexels") {
                SecureField("API Key", text: $pexelsKey)
                    .onChange(of: pexelsKey) { _, value in SettingsStore.shared.pexelsAPIKey = value }
                Link("Get a free Pexels API key", destination: URL(string: "https://www.pexels.com/api/")!)
                    .font(.caption)
            }
            Section("Pixabay") {
                SecureField("API Key", text: $pixabayKey)
                    .onChange(of: pixabayKey) { _, value in SettingsStore.shared.pixabayAPIKey = value }
                Link("Get a free Pixabay API key", destination: URL(string: "https://pixabay.com/api/docs/")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PlaybackSettingsTab: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var isMuted = SettingsStore.shared.isMuted
    @State private var isLooping = SettingsStore.shared.isLooping
    @State private var restoreOnLaunch = SettingsStore.shared.restoreOnLaunch

    var body: some View {
        Form {
            Toggle("Mute video wallpapers", isOn: $isMuted)
                .onChange(of: isMuted) { _, value in WallpaperEngine.shared.setMuted(value) }
            Toggle("Loop wallpapers continuously", isOn: $isLooping)
                .onChange(of: isLooping) { _, value in WallpaperEngine.shared.setLooping(value) }
            Toggle("Restore last wallpaper on launch", isOn: $restoreOnLaunch)
                .onChange(of: restoreOnLaunch) { _, value in settings.restoreOnLaunch = value }
        }
        .formStyle(.grouped)
    }
}

private struct AutoChangeSettingsTab: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var enabled = SettingsStore.shared.autoChangeEnabled
    @State private var interval = SettingsStore.shared.autoChangeInterval
    @State private var source = SettingsStore.shared.autoChangeSource

    var body: some View {
        Form {
            Toggle("Automatically change wallpaper", isOn: $enabled)
                .onChange(of: enabled) { _, value in
                    settings.autoChangeEnabled = value
                    value ? WallpaperEngine.shared.startAutoChange() : WallpaperEngine.shared.stopAutoChange()
                }
            Picker("Frequency", selection: $interval) {
                ForEach(AutoChangeInterval.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .disabled(!enabled)
            .onChange(of: interval) { _, value in
                settings.autoChangeInterval = value
                if enabled { WallpaperEngine.shared.startAutoChange() }
            }
            Picker("Pull from", selection: $source) {
                ForEach(AutoChangeSource.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .disabled(!enabled)
            .onChange(of: source) { _, value in settings.autoChangeSource = value }
        }
        .formStyle(.grouped)
    }
}

private struct PerformanceSettingsTab: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var pauseOnBattery = SettingsStore.shared.pauseOnBattery
    @State private var pauseWhenFullscreen = SettingsStore.shared.pauseWhenFullscreenAppActive
    @State private var launchAtLogin = SettingsStore.shared.launchAtLogin

    var body: some View {
        Form {
            Toggle("Pause wallpaper on battery power", isOn: $pauseOnBattery)
                .onChange(of: pauseOnBattery) { _, value in settings.pauseOnBattery = value }
            Toggle("Pause when another app is fullscreen", isOn: $pauseWhenFullscreen)
                .onChange(of: pauseWhenFullscreen) { _, value in settings.pauseWhenFullscreenAppActive = value }
            Toggle("Launch Electron at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, value in
                    settings.launchAtLogin = value
                    do {
                        if value {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Non-fatal: the toggle simply won't stick if the
                        // system declines the login-item request.
                    }
                }
            Text("Electron pauses playback automatically when your Mac sleeps or the screen is locked, so it never wastes power while you're away.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct StorageSettingsTab: View {
    @State private var cacheSizeDescription = "Calculating…"
    @State private var maxCacheGB: Double = Double(SettingsStore.shared.maxCacheBytes) / 1_000_000_000

    var body: some View {
        Form {
            LabeledContent("Downloaded wallpapers", value: cacheSizeDescription)
            Slider(value: $maxCacheGB, in: 0.5...10, step: 0.5) {
                Text("Cache limit")
            }
            .onChange(of: maxCacheGB) { _, value in
                SettingsStore.shared.maxCacheBytes = Int64(value * 1_000_000_000)
                DownloadManager.shared.enforceCacheLimit()
            }
            Text("Limit: \(maxCacheGB, specifier: "%.1f") GB")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Clear Downloaded Wallpapers", role: .destructive) {
                clearAll()
            }
        }
        .formStyle(.grouped)
        .task { await calculateCacheSize() }
    }

    private func calculateCacheSize() async {
        let dir = FileStorage.wallpapersDirectory()
        let size = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]))?
            .reduce(0) { total, url in
                total + ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            } ?? 0
        cacheSizeDescription = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func clearAll() {
        let dir = FileStorage.wallpapersDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        Task { await calculateCacheSize() }
    }
}

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 48))
            Text("Electron").font(.title2.bold())
            Text("A free, open-source live wallpaper app for macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Link("View Source on GitHub", destination: URL(string: "https://github.com/your-org/electron")!)
            Text("Released under the MIT License.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
