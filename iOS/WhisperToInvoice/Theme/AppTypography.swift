import SwiftUI

/// Nunito faces bundled with the app (the same font files as the Android app).
enum NunitoWeight: String {
    case extraLight = "Nunito-ExtraLight"
    case light = "Nunito-Light"
    case regular = "Nunito-Regular"
    case medium = "Nunito-Medium"
    case semiBold = "Nunito-SemiBold"
    case bold = "Nunito-Bold"
    case extraBold = "Nunito-ExtraBold"
    case black = "Nunito-Black"
}

/// The Material 3 type scale used by the Android app (size, weight and letter spacing), rendered
/// with Nunito and scaled with Dynamic Type.
enum AppTextStyle {
    case displayLarge, displayMedium, displaySmall
    case headlineLarge, headlineMedium, headlineSmall
    case titleLarge, titleMedium, titleSmall
    case bodyLarge, bodyMedium, bodySmall
    case labelLarge, labelMedium, labelSmall

    var size: CGFloat {
        switch self {
        case .displayLarge: 57
        case .displayMedium: 45
        case .displaySmall: 36
        case .headlineLarge: 32
        case .headlineMedium: 28
        case .headlineSmall: 24
        case .titleLarge: 22
        case .titleMedium: 16
        case .titleSmall: 14
        case .bodyLarge: 16
        case .bodyMedium: 14
        case .bodySmall: 12
        case .labelLarge: 14
        case .labelMedium: 12
        case .labelSmall: 11
        }
    }

    var defaultWeight: NunitoWeight {
        switch self {
        case .titleMedium, .titleSmall, .labelLarge, .labelMedium, .labelSmall: .medium
        default: .regular
        }
    }

    /// Letter spacing in points (Material 3 baseline).
    var tracking: CGFloat {
        switch self {
        case .displayLarge: -0.25
        case .titleMedium: 0.15
        case .titleSmall: 0.1
        case .bodyLarge: 0.5
        case .bodyMedium: 0.25
        case .bodySmall: 0.4
        case .labelLarge: 0.1
        case .labelMedium: 0.5
        case .labelSmall: 0.5
        default: 0
        }
    }

    /// The system text style used to scale this style with Dynamic Type.
    var relativeTextStyle: Font.TextStyle {
        switch self {
        case .displayLarge, .displayMedium, .displaySmall: .largeTitle
        case .headlineLarge: .title
        case .headlineMedium: .title2
        case .headlineSmall: .title3
        case .titleLarge: .title3
        case .titleMedium: .headline
        case .titleSmall: .subheadline
        case .bodyLarge: .body
        case .bodyMedium: .callout
        case .bodySmall: .footnote
        case .labelLarge: .subheadline
        case .labelMedium: .caption
        case .labelSmall: .caption2
        }
    }
}

extension Font {
    /// A Nunito font for the given Material style. A `weight` of `nil` uses the style's default.
    static func app(_ style: AppTextStyle, weight: NunitoWeight? = nil) -> Font {
        .custom(
            (weight ?? style.defaultWeight).rawValue,
            size: style.size,
            relativeTo: style.relativeTextStyle)
    }

    /// A Nunito font with an explicit size (scaled with Dynamic Type relative to `textStyle`).
    static func app(size: CGFloat, weight: NunitoWeight = .regular, relativeTo textStyle: Font.TextStyle = .body)
        -> Font
    {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}

extension View {
    /// Applies a Material type-scale style (font + letter spacing).
    func appText(_ style: AppTextStyle, weight: NunitoWeight? = nil) -> some View {
        font(.app(style, weight: weight)).tracking(style.tracking)
    }
}
