import Foundation
import UIKit

/// The seller's details printed on every invoice. Port of Android `BusinessProfile`.
struct BusinessProfile: Equatable, Sendable {
    var businessName: String = ""
    var tagline: String = ""
    var address: String = ""
    var phone: String = ""
    var email: String = ""
    var paymentInstructions: String = ""
    /// Non-empty when a logo has been imported. The file itself always lives at
    /// `BusinessProfileRepository.logoURL` (iOS container paths are not stable, so the stored
    /// string is only a marker and is never used to locate the file).
    var logoPath: String = ""

    var isEmpty: Bool { businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Stores the business profile in `UserDefaults` and the logo in Application Support
/// (Android: `SharedPreferences("business_profile")` + `filesDir/logo/logo.png`).
final class BusinessProfileRepository: @unchecked Sendable {
    private enum Key {
        static let prefix = "business_profile."
        static let businessName = prefix + "businessName"
        static let tagline = prefix + "tagline"
        static let address = prefix + "address"
        static let phone = prefix + "phone"
        static let email = prefix + "email"
        static let paymentInstructions = prefix + "paymentInstructions"
        static let logoPath = prefix + "logoPath"
    }

    /// The longest side of a stored logo, in pixels. Bounds memory use and PDF size.
    static let maxLogoDimension: CGFloat = 1024

    private let defaults: UserDefaults
    private let logoDirectory: URL

    init(defaults: UserDefaults = .standard, baseDirectory: URL? = nil) {
        self.defaults = defaults
        let base = baseDirectory ?? AppDirectories.applicationSupport
        self.logoDirectory = base.appendingPathComponent("logo", isDirectory: true)
        try? FileManager.default.createDirectory(at: logoDirectory, withIntermediateDirectories: true)
    }

    var logoURL: URL { logoDirectory.appendingPathComponent("logo.png") }

    func get() -> BusinessProfile {
        BusinessProfile(
            businessName: defaults.string(forKey: Key.businessName) ?? "",
            tagline: defaults.string(forKey: Key.tagline) ?? "",
            address: defaults.string(forKey: Key.address) ?? "",
            phone: defaults.string(forKey: Key.phone) ?? "",
            email: defaults.string(forKey: Key.email) ?? "",
            paymentInstructions: defaults.string(forKey: Key.paymentInstructions) ?? "",
            logoPath: defaults.string(forKey: Key.logoPath) ?? "")
    }

    func save(_ profile: BusinessProfile) {
        defaults.set(profile.businessName, forKey: Key.businessName)
        defaults.set(profile.tagline, forKey: Key.tagline)
        defaults.set(profile.address, forKey: Key.address)
        defaults.set(profile.phone, forKey: Key.phone)
        defaults.set(profile.email, forKey: Key.email)
        defaults.set(profile.paymentInstructions, forKey: Key.paymentInstructions)
        defaults.set(profile.logoPath, forKey: Key.logoPath)
        AppLog.profile.info("Business profile saved (hasLogo=\(!profile.logoPath.isEmpty, privacy: .public))")
    }

    /// Decodes the picked image data, downsizes it, re-encodes it as PNG (this also strips any
    /// embedded metadata) and stores it as the logo. Returns the marker to store in
    /// `BusinessProfile.logoPath`. Call on a background thread.
    func importLogo(from data: Data) throws -> String {
        guard let source = UIImage(data: data) else {
            AppLog.profile.error("Logo import failed: data is not a decodable image")
            throw LogoImportError.unreadableImage
        }
        let normalized = Self.downscaled(source, maxDimension: Self.maxLogoDimension)
        guard let png = normalized.pngData() else {
            AppLog.profile.error("Logo import failed: could not encode PNG")
            throw LogoImportError.encodingFailed
        }
        try FileManager.default.createDirectory(at: logoDirectory, withIntermediateDirectories: true)
        try png.write(to: logoURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        AppLog.profile.info("Logo imported: \(Int(normalized.size.width))x\(Int(normalized.size.height)) px, \(png.count) bytes")
        return logoURL.path
    }

    /// Loads the stored logo, if any.
    func loadLogo() -> UIImage? {
        guard FileManager.default.fileExists(atPath: logoURL.path) else { return nil }
        return UIImage(contentsOfFile: logoURL.path)
    }

    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

enum LogoImportError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "The selected file is not a readable image."
        case .encodingFailed: "The logo could not be saved."
        }
    }
}
