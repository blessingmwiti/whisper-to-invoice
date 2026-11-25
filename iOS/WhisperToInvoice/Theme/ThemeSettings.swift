import Observation
import SwiftUI

/// Theme override chosen in Settings (Android: `Theme.THEME_AUTO / THEME_LIGHT / THEME_DARK`).
enum ThemeOverride: String, CaseIterable, Identifiable, Sendable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// `nil` means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Holds and persists the user's theme override.
@MainActor
@Observable
final class ThemeSettings {
    private static let storageKey = "theme_override"

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var themeOverride: ThemeOverride

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.storageKey) ?? ThemeOverride.auto.rawValue
        self.themeOverride = ThemeOverride(rawValue: stored) ?? .auto
    }

    func select(_ theme: ThemeOverride) {
        themeOverride = theme
        defaults.set(theme.rawValue, forKey: Self.storageKey)
        AppLog.theme.info("Theme override set to \(theme.rawValue, privacy: .public)")
    }
}
