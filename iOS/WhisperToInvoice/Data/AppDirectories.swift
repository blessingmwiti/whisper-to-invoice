import Foundation

/// App-private storage locations (Android: `context.filesDir` / `getExternalFilesDir`).
enum AppDirectories {
    /// `Application Support/` — created on demand.
    static var applicationSupport: URL {
        let fm = FileManager.default
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Where downloaded models live. Excluded from iCloud/iTunes backups (large, re-downloadable).
    static var models: URL {
        let url = applicationSupport.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
        return url
    }

    /// Writable cache directory for the LiteRT-LM engine (compiled GPU programs, etc).
    static var engineCache: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("litertlm", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
