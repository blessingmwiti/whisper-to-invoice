import SwiftUI
import UIKit

// MARK: - Color helpers

extension UIColor {
    /// Creates a color from an Android-style `0xAARRGGBB` value.
    convenience init(argb: UInt32) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    /// Creates a color from an Android-style `0xAARRGGBB` value.
    init(argb: UInt32) {
        self.init(uiColor: UIColor(argb: argb))
    }

    /// Creates a color that follows the interface style (light / dark), using Android-style
    /// `0xAARRGGBB` values.
    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(argb: traits.userInterfaceStyle == .dark ? dark : light)
            })
    }
}

// MARK: - Palette

/// The global color system of the app.
///
/// Every value in this file is copied 1:1 from the Android app (`ui/theme/Color.kt` and the
/// `lightCustomColors` / `darkCustomColors` in `ui/theme/Theme.kt`) so both platforms share the
/// exact same colors. Only the *surfaces* differ: Android renders them with Material Design,
/// iOS renders chrome and controls with Liquid Glass.
enum AppPalette {

    // MARK: Material color roles (Color.kt)

    static let primary = Color(light: 0xFF0B57D0, dark: 0xFFA8C7FA)
    static let onPrimary = Color(light: 0xFFFFFFFF, dark: 0xFF062E6F)
    static let primaryContainer = Color(light: 0xFFD3E3FD, dark: 0xFF0842A0)
    static let onPrimaryContainer = Color(light: 0xFF0842A0, dark: 0xFFD3E3FD)

    static let secondary = Color(light: 0xFF00639B, dark: 0xFF7FCFFF)
    static let onSecondary = Color(light: 0xFFFFFFFF, dark: 0xFF003355)
    static let secondaryContainer = Color(light: 0xFFC2E7FF, dark: 0xFF004A77)
    static let onSecondaryContainer = Color(light: 0xFF004A77, dark: 0xFFC2E7FF)

    static let tertiary = Color(light: 0xFF146C2E, dark: 0xFF6DD58C)
    static let onTertiary = Color(light: 0xFFFFFFFF, dark: 0xFF0A3818)
    static let tertiaryContainer = Color(light: 0xFFC4EED0, dark: 0xFF0F5223)
    static let onTertiaryContainer = Color(light: 0xFF0F5223, dark: 0xFFC4EED0)

    static let error = Color(light: 0xFFB3261E, dark: 0xFFF2B8B5)
    static let onError = Color(light: 0xFFFFFFFF, dark: 0xFF601410)
    static let errorContainer = Color(light: 0xFFF9DEDC, dark: 0xFF8C1D18)
    static let onErrorContainer = Color(light: 0xFF8C1D18, dark: 0xFFF9DEDC)

    static let background = Color(light: 0xFFFFFFFF, dark: 0xFF131314)
    static let onBackground = Color(light: 0xFF1F1F1F, dark: 0xFFE3E3E3)
    static let surface = Color(light: 0xFFFFFFFF, dark: 0xFF131314)
    static let onSurface = Color(light: 0xFF1F1F1F, dark: 0xFFE3E3E3)
    static let surfaceVariant = Color(light: 0xFFE1E3E1, dark: 0xFF444746)
    static let onSurfaceVariant = Color(light: 0xFF444746, dark: 0xFFC4C7C5)

    static let surfaceContainerLowest = Color(light: 0xFFFFFFFF, dark: 0xFF0E0E0E)
    static let surfaceContainerLow = Color(light: 0xFFF8FAFD, dark: 0xFF1B1B1B)
    static let surfaceContainer = Color(light: 0xFFF0F4F9, dark: 0xFF1E1F20)
    static let surfaceContainerHigh = Color(light: 0xFFE9EEF6, dark: 0xFF282A2C)
    static let surfaceContainerHighest = Color(light: 0xFFDDE3EA, dark: 0xFF333537)

    static let inverseSurface = Color(light: 0xFF303030, dark: 0xFFE3E3E3)
    static let inverseOnSurface = Color(light: 0xFFF2F2F2, dark: 0xFF303030)
    static let outline = Color(light: 0xFF747775, dark: 0xFF8E918F)
    static let outlineVariant = Color(light: 0xFFC4C7C5, dark: 0xFF444746)
    static let inversePrimary = Color(light: 0xFFA8C7FA, dark: 0xFF0B57D0)
    static let surfaceDim = Color(light: 0xFFD3DBE5, dark: 0xFF131314)
    static let surfaceBright = Color(light: 0xFFFFFFFF, dark: 0xFF37393B)
    static let scrim = Color(argb: 0xFF000000)

    // MARK: Custom colors (Theme.kt)

    static let appTitleGradient: [Color] = [Color(argb: 0xFF85B1F8), Color(argb: 0xFF3174F1)]
    static let tabHeaderBg = Color(argb: 0xFF3174F1)

    /// Light: `surfaceContainerLowest`, dark: `surfaceContainerHigh`.
    static let taskCardBg = Color(light: 0xFFFFFFFF, dark: 0xFF282A2C)

    /// red, green, blue, yellow.
    static let taskBgColors: [Color] = [
        Color(light: 0xFFFFF5F5, dark: 0xFF181210),
        Color(light: 0xFFF4FBF6, dark: 0xFF131711),
        Color(light: 0xFFF1F6FE, dark: 0xFF191924),
        Color(light: 0xFFFFFBF0, dark: 0xFF1A1813),
    ]

    /// red, green, blue, yellow (same in light and dark).
    static let taskBgGradientPairs: [[UInt32]] = [
        [0xFFE25F57, 0xFFDB372D],
        [0xFF41A15F, 0xFF128937],
        [0xFF669DF6, 0xFF3174F1],
        [0xFFFDD45D, 0xFFCAA12A],
    ]

    /// red, green, blue, yellow.
    static let taskIconColors: [Color] = [
        Color(light: 0xFFDB372D, dark: 0xFFE25F57),
        Color(light: 0xFF128937, dark: 0xFF41A15F),
        Color(light: 0xFF3174F1, dark: 0xFF669DF6),
        Color(light: 0xFFCAA12A, dark: 0xFFCAA12A),
    ]

    static let taskIconShapeBg = Color(light: 0xFFFFFFFF, dark: 0xFF202124)
    static let homeBottomGradient: [Color] = [
        Color(light: 0x00F8F9FF, dark: 0x00F8F9FF),
        Color(light: 0xFFFFEFC9, dark: 0x1AF6AD01),
    ]
    static let agentBubbleBg = Color(light: 0xFFE9EEF6, dark: 0xFF1B1C1D)
    static let userBubbleBg = Color(light: 0xFF32628D, dark: 0xFF1F3760)
    static let link = Color(light: 0xFF32628D, dark: 0xFF9DCAFC)
    static let success = Color(light: 0xFF3D860B, dark: 0xFFA1CE83)
    static let recordButtonBg = Color(argb: 0xFFEE675C)
    static let waveFormBg = Color(argb: 0xFFAAAAAA)
    static let modelInfoIcon = Color(argb: 0xFFCCCCCC)
    static let warningContainer = Color(light: 0xFFFEF7E0, dark: 0xFF554C33)
    static let warningText = Color(light: 0xFFE37400, dark: 0xFFFCC934)
    static let errorContainerCustom = Color(light: 0xFFFCE8E6, dark: 0xFF523A3B)
    static let errorText = Color(light: 0xFFD93025, dark: 0xFFEE675C)
    static let newFeatureContainer = Color(argb: 0xFFEEDCFE)
    static let newFeatureText = Color(argb: 0xFF400B84)
    static let bgStar = Color(light: 0x3A669AF5, dark: 0x19346BF0)

    /// Promo banner background (Android `promoBannerBgBrush`, vertical gradient). Light mode has
    /// stops at 0 / 0.6154 / 1.0 and dark mode at 0 / 0.8077; the stops below combine both and
    /// carry the interpolated colour of the other scheme where one has no stop of its own.
    static let promoBannerBg = LinearGradient(
        stops: [
            .init(color: Color(light: 0x42ACB7FF, dark: 0x82183570), location: 0.0),
            .init(color: Color(light: 0x422D96FF, dark: 0x820D1A3D), location: 0.6154),
            .init(color: Color(light: 0x423580FF, dark: 0x820A122D), location: 0.8077),
            .init(color: Color(light: 0x423C6BFF, dark: 0x820A122D), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom)

    /// Promo banner star tint (Android `promoBannerIconBgBrush`, bottom-leading to top-trailing).
    static let promoBannerIcon = LinearGradient(
        stops: [
            .init(color: Color(light: 0x3B446EFF, dark: 0x6F0F41F8), location: 0.2442),
            .init(color: Color(light: 0x3B2E96FF, dark: 0x6F1685F8), location: 0.4296),
            .init(color: Color(light: 0x3BB1C5FF, dark: 0x6F809EF3), location: 0.6651),
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing)

    // MARK: Task color helpers (ui/common/ColorUtils.kt)

    private static func wrapped(_ index: Int, count: Int) -> Int {
        max(index, 0) % count
    }

    static func taskBgColor(index: Int) -> Color {
        taskBgColors[wrapped(index, count: taskBgColors.count)]
    }

    static func taskBgGradientColors(index: Int) -> [Color] {
        taskBgGradientPairs[wrapped(index, count: taskBgGradientPairs.count)].map { Color(argb: $0) }
    }

    static func taskGradient(index: Int) -> LinearGradient {
        LinearGradient(
            colors: taskBgGradientColors(index: index),
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    static func taskIconColor(index: Int) -> Color {
        taskIconColors[wrapped(index, count: taskIconColors.count)]
    }
}
