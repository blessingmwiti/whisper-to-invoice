import Foundation

/// Navigation destinations (Android: `GalleryNavGraph` routes).
enum Route: Hashable {
    case modelList
    case model
    case globalModels
    case businessProfile
    case invoiceList
    case about
    case privacy
    case licenses
}

/// App-wide constants.
enum AppInfo {
    static let name = "Whisper to Invoice"
    static let taskLabel = "Whisper to Invoice"
    static let taskDescription =
        "Speak your sale in any language — Gemma 4 extracts it into a professional invoice, 100% offline."
    static let taskShortDescription = "Voice → Invoice, offline"
    static let intro = "Voice to professional invoice — 100% offline, powered by Gemma 4"

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
