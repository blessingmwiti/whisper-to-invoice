import Foundation
import Observation
import UIKit
import UserNotifications

/// Download state of the model (Android: `ModelDownloadStatus`).
enum ModelDownloadStatus: Equatable, Sendable {
    case notDownloaded
    case partiallyDownloaded(received: Int64, total: Int64)
    case inProgress(received: Int64, total: Int64, bytesPerSecond: Int64)
    case succeeded
    case failed(message: String)
}

/// Initialization state of the model (Android: `ModelInitializationStatusType`).
enum ModelInitStatus: Equatable, Sendable {
    case notInitialized
    case initializing
    case initialized
    case error(String)
}

/// Owns the model's download and initialization state (Android: `ModelManagerViewModel`).
@MainActor
@Observable
final class ModelManager {
    private enum DefaultsKey {
        static let partialReceived = "model_partial_received_bytes"
    }

    /// The one model the app ships with.
    let model: LlmModel
    /// Models shown in the model list.
    var models: [LlmModel] { [model] }

    private(set) var downloadStatus: ModelDownloadStatus = .notDownloaded
    private(set) var initStatus: ModelInitStatus = .notInitialized
    private(set) var config: LlmConfig

    /// The LiteRT-LM wrapper that the invoice flow runs inference on.
    @ObservationIgnored let helper = LlmChatModelHelper()

    @ObservationIgnored private let downloader: ModelDownloader
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var initGeneration = 0
    @ObservationIgnored private var lastReceivedBytes: Int64 = 0

    init(model: LlmModel = .gemma4E2B, defaults: UserDefaults = .standard) {
        self.model = model
        self.defaults = defaults
        self.config = model.defaultConfig
        self.downloader = ModelDownloader(model: model)
        listenForDownloadEvents()
        Task { await refreshDownloadStatus() }
    }

    // MARK: - Paths and device checks

    var modelFileURL: URL { downloader.modelFileURL }

    /// True when the device has less memory than the model needs. Uses decimal GB, which matches
    /// the RAM size devices are sold with.
    var isMemoryLow: Bool {
        let advertisedGb = (Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000).rounded()
        AppLog.modelManager.debug(
            "Device memory (GB): \(advertisedGb, privacy: .public). Required: \(self.model.minDeviceMemoryInGb, privacy: .public)")
        return advertisedGb < Double(model.minDeviceMemoryInGb)
    }

    // MARK: - Download

    /// Works out the current status from what is on disk and what the background session is doing.
    func refreshDownloadStatus() async {
        if isModelFileComplete() {
            downloadStatus = .succeeded
            return
        }
        if await downloader.reattachToRunningDownload() {
            if case .inProgress = downloadStatus { return }
            downloadStatus = .inProgress(received: lastReceivedBytes, total: model.sizeInBytes, bytesPerSecond: 0)
            return
        }
        if downloader.hasPartialDownload {
            let received = Int64(defaults.integer(forKey: DefaultsKey.partialReceived))
            downloadStatus = .partiallyDownloaded(received: received, total: model.sizeInBytes)
        } else if case .failed = downloadStatus {
            // Keep the failure message visible.
        } else {
            downloadStatus = .notDownloaded
        }
    }

    private func isModelFileComplete() -> Bool {
        let path = downloader.modelFileURL.path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let size = (attributes[.size] as? NSNumber)?.int64Value
        else { return false }
        return size == model.sizeInBytes
    }

    /// Result of the pre-download reachability check.
    enum DownloadPreflightResult: Equatable {
        case ok
        case networkError
        case httpError(Int)
    }

    /// Android: `getModelUrlResponse`. Checks that the download URL is reachable before starting.
    func preflightDownload() async -> DownloadPreflightResult {
        var request = URLRequest(url: model.downloadURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 20
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLog.download.info("Preflight HTTP status: \(status, privacy: .public)")
            if (200...299).contains(status) { return .ok }
            if status < 0 { return .networkError }
            return .httpError(status)
        } catch {
            AppLog.download.error("Preflight failed: \(error.localizedDescription, privacy: .public)")
            return .networkError
        }
    }

    func startDownload() {
        guard downloadStatus != .succeeded else { return }
        lastReceivedBytes = 0
        downloadStatus = .inProgress(received: 0, total: model.sizeInBytes, bytesPerSecond: 0)
        Task {
            await Self.requestNotificationAuthorization()
            await downloader.start()
        }
    }

    func cancelDownload() {
        Task {
            await downloader.cancel()
            if downloader.hasPartialDownload {
                defaults.set(Int(lastReceivedBytes), forKey: DefaultsKey.partialReceived)
                downloadStatus = .partiallyDownloaded(received: lastReceivedBytes, total: model.sizeInBytes)
            } else {
                downloadStatus = .notDownloaded
            }
        }
    }

    /// Deletes the downloaded model file (Android: `deleteModel`).
    func deleteModel() async {
        await downloader.cancel()
        await helper.cleanUp()
        initStatus = .notInitialized
        initGeneration += 1
        downloader.discardPartialDownload()
        defaults.removeObject(forKey: DefaultsKey.partialReceived)
        let directory = downloader.modelFileURL.deletingLastPathComponent()
        do {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            AppLog.modelManager.info("Model files deleted")
        } catch {
            AppLog.modelManager.error("Failed to delete model files: \(error.localizedDescription, privacy: .public)")
        }
        lastReceivedBytes = 0
        downloadStatus = .notDownloaded
    }

    private func listenForDownloadEvents() {
        let events = downloader.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    private func handle(_ event: DownloadEvent) {
        switch event {
        case .progress(let received, let total, let bytesPerSecond):
            lastReceivedBytes = received
            downloadStatus = .inProgress(received: received, total: total, bytesPerSecond: bytesPerSecond)
        case .completed:
            downloadStatus = .succeeded
            defaults.removeObject(forKey: DefaultsKey.partialReceived)
            Self.postNotification(
                title: "Model download succeeded",
                body: "Model \"\(model.name)\" has been downloaded")
        case .failed(let message):
            if downloader.hasPartialDownload {
                defaults.set(Int(lastReceivedBytes), forKey: DefaultsKey.partialReceived)
            }
            downloadStatus = .failed(message: message)
            Self.postNotification(
                title: "Model download failed",
                body: "Failed to download model \"\(model.name)\"")
        }
    }

    // MARK: - Initialization

    /// Loads the model into memory. Does nothing if it is already loaded unless `force` is set.
    func initializeModel(force: Bool = false) {
        guard downloadStatus == .succeeded else {
            AppLog.modelManager.warning("initializeModel ignored: model is not downloaded")
            return
        }
        if !force {
            switch initStatus {
            case .initializing, .initialized: return
            default: break
            }
        }

        initGeneration += 1
        let generation = initGeneration
        initStatus = .initializing
        let path = downloader.modelFileURL.path
        let config = self.config
        let helper = self.helper
        Task {
            do {
                try await helper.initialize(modelPath: path, config: config)
                if generation == self.initGeneration { self.initStatus = .initialized }
            } catch {
                AppLog.modelManager.error("Model initialization failed: \(error.localizedDescription, privacy: .public)")
                if generation == self.initGeneration {
                    self.initStatus = .error(error.localizedDescription)
                }
            }
        }
    }

    /// Releases the model from memory (Android: `cleanupModel`).
    func cleanUpModel() {
        initGeneration += 1
        initStatus = .notInitialized
        let helper = self.helper
        Task { await helper.cleanUp() }
    }

    /// Applies new settings; the model is re-initialized because every setting needs a reload.
    func updateConfig(_ newConfig: LlmConfig) {
        guard newConfig != config else { return }
        AppLog.modelManager.info(
            """
            Config changed: accelerator=\(newConfig.accelerator.rawValue, privacy: .public) \
            maxTokens=\(newConfig.maxTokens, privacy: .public) topK=\(newConfig.topK, privacy: .public) \
            topP=\(newConfig.topP, privacy: .public) temperature=\(newConfig.temperature, privacy: .public)
            """)
        config = newConfig
        initializeModel(force: true)
    }

    // MARK: - Notifications

    private static func requestNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    private static func postNotification(title: String, body: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.modelManager.error("Could not post notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
