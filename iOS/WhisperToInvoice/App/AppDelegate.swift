import UIKit

/// Receives the system callback that relaunches the app when the background model download
/// finishes, and hands it to `ModelDownloader` (which calls it once all events are delivered).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        AppLog.download.info("Relaunched for background URLSession events: \(identifier, privacy: .public)")
        // The downloader calls this on the main queue, which is where UIKit expects it.
        nonisolated(unsafe) let handler = completionHandler
        ModelDownloader.backgroundCompletionHandler.withLock { stored in
            stored = {
                MainActor.assumeIsolated { handler() }
            }
        }
    }
}
