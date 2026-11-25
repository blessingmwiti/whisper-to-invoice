import Foundation
import UIKit
import os

/// Events emitted by `ModelDownloader`.
enum DownloadEvent: Sendable {
    case progress(received: Int64, total: Int64, bytesPerSecond: Int64)
    case completed
    case failed(message: String)
}

/// Downloads the model file with a background `URLSession`, so a download keeps going when the app
/// is suspended and can be resumed after a failure (Android: `DownloadWorker` + WorkManager).
final class ModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    static let sessionIdentifier = "\(AppLog.subsystem).modeldownload"

    /// Set by the app delegate when iOS relaunches the app to deliver background session events.
    static let backgroundCompletionHandler = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)

    let events: AsyncStream<DownloadEvent>
    private let continuation: AsyncStream<DownloadEvent>.Continuation

    private let model: LlmModel
    private let destinationURL: URL
    private let resumeDataURL: URL

    private struct SpeedState {
        var lastSampleTime = Date()
        var lastSampleBytes: Int64 = 0
        var bytesPerSecond: Int64 = 0
    }
    private let speed = OSAllocatedUnfairLock(initialState: SpeedState())
    private let userCancelled = OSAllocatedUnfairLock(initialState: false)

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    init(model: LlmModel, modelsDirectory: URL = AppDirectories.models) {
        self.model = model
        self.destinationURL = modelsDirectory.appendingPathComponent(model.relativePath)
        self.resumeDataURL = modelsDirectory.appendingPathComponent(model.relativePath + ".resume")
        var continuation: AsyncStream<DownloadEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation = $0 }
        self.continuation = continuation
        super.init()
    }

    var modelFileURL: URL { destinationURL }

    /// True when a previous attempt left resume data on disk.
    var hasPartialDownload: Bool { FileManager.default.fileExists(atPath: resumeDataURL.path) }

    /// Reconnects to a download that was already running (for example before the app was killed).
    /// Returns `true` if a task is in flight.
    func reattachToRunningDownload() async -> Bool {
        let tasks = await session.allTasks
        let running = tasks.filter { $0.state == .running || $0.state == .suspended }
        if !running.isEmpty {
            AppLog.download.info("Reattached to \(running.count, privacy: .public) running download task(s)")
        }
        for task in running { task.resume() }
        return !running.isEmpty
    }

    /// Starts a fresh download or resumes a partial one.
    func start() async {
        userCancelled.withLock { $0 = false }
        speed.withLock { $0 = SpeedState() }

        // Never run two downloads at once.
        let existing = await session.allTasks
        for task in existing { task.cancel() }

        do {
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            AppLog.download.error("Cannot create model directory: \(error.localizedDescription, privacy: .public)")
            continuation.yield(.failed(message: "Could not prepare storage: \(error.localizedDescription)"))
            return
        }

        if let resumeData = try? Data(contentsOf: resumeDataURL), !resumeData.isEmpty {
            AppLog.download.info("Resuming download from saved resume data (\(resumeData.count, privacy: .public) bytes)")
            try? FileManager.default.removeItem(at: resumeDataURL)
            let task = session.downloadTask(withResumeData: resumeData)
            task.taskDescription = model.name
            task.resume()
            return
        }

        AppLog.download.info("Starting download of \(self.model.name, privacy: .public)")
        var request = URLRequest(url: model.downloadURL)
        request.httpMethod = "GET"
        request.setValue("WhisperToInvoice-iOS", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        task.taskDescription = model.name
        task.resume()
    }

    /// Cancels the running download, keeping what was downloaded so far when possible.
    func cancel() async {
        userCancelled.withLock { $0 = true }
        let tasks = await session.allTasks
        for task in tasks {
            guard let downloadTask = task as? URLSessionDownloadTask else {
                task.cancel()
                continue
            }
            let resumeData = await downloadTask.cancelByProducingResumeData()
            if let resumeData, !resumeData.isEmpty {
                try? FileManager.default.createDirectory(
                    at: resumeDataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? resumeData.write(to: resumeDataURL, options: .atomic)
                AppLog.download.info("Download cancelled, resume data saved (\(resumeData.count, privacy: .public) bytes)")
            } else {
                AppLog.download.info("Download cancelled, no resume data available")
            }
        }
    }

    /// Removes any partial download state.
    func discardPartialDownload() {
        try? FileManager.default.removeItem(at: resumeDataURL)
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : model.sizeInBytes
        let bytesPerSecond = speed.withLock { state -> Int64 in
            let now = Date()
            let elapsed = now.timeIntervalSince(state.lastSampleTime)
            if elapsed >= 1.0 {
                state.bytesPerSecond = Int64(Double(totalBytesWritten - state.lastSampleBytes) / elapsed)
                state.lastSampleTime = now
                state.lastSampleBytes = totalBytesWritten
            }
            return max(state.bytesPerSecond, 0)
        }
        continuation.yield(.progress(received: totalBytesWritten, total: total, bytesPerSecond: bytesPerSecond))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // This runs before the temporary file is removed, so it must be moved right here.
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            AppLog.download.error("Download finished with HTTP status \(status, privacy: .public)")
            continuation.yield(.failed(message: "Download failed (HTTP \(status))."))
            return
        }

        let fm = FileManager.default
        do {
            let attributes = try fm.attributesOfItem(atPath: location.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            guard size == model.sizeInBytes else {
                AppLog.download.error("Downloaded size \(size, privacy: .public) != expected \(self.model.sizeInBytes, privacy: .public)")
                continuation.yield(.failed(message: "The downloaded file is incomplete or corrupted. Please try again."))
                return
            }

            try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: location, to: destinationURL)

            // Keep the large file out of backups and protected until first unlock.
            var url = destinationURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
            try? fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: destinationURL.path)

            try? fm.removeItem(at: resumeDataURL)
            AppLog.download.info("Model downloaded and stored (\(size, privacy: .public) bytes)")
            continuation.yield(.completed)
        } catch {
            AppLog.download.error("Could not store downloaded model: \(error.localizedDescription, privacy: .public)")
            continuation.yield(.failed(message: "Could not save the model: \(error.localizedDescription)"))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            // User cancellation is reported by the caller; a replaced task also lands here.
            if !userCancelled.withLock({ $0 }) {
                AppLog.download.info("Download task cancelled (replaced by a newer task)")
            }
            return
        }

        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data, !resumeData.isEmpty {
            try? FileManager.default.createDirectory(
                at: resumeDataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? resumeData.write(to: resumeDataURL, options: .atomic)
            AppLog.download.info("Saved resume data after failure (\(resumeData.count, privacy: .public) bytes)")
        }
        AppLog.download.error(
            "Download failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) \(error.localizedDescription, privacy: .public)")
        continuation.yield(.failed(message: error.localizedDescription))
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = Self.backgroundCompletionHandler.withLock { stored -> (@Sendable () -> Void)? in
            let value = stored
            stored = nil
            return value
        }
        if let handler {
            DispatchQueue.main.async { handler() }
        }
    }
}
