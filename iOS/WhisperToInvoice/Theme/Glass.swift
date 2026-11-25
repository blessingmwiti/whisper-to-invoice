import SwiftUI

// MARK: - Liquid Glass helpers
//
// Android keeps Material Design. On iOS the same palette (`AppPalette`) is rendered with Liquid
// Glass: navigation, floating controls, tiles and hero cards use the system glass material
// (`glassEffect`), while dense editable content sits on solid palette surfaces so text stays
// readable (Apple's guidance: glass is for the controls/navigation layer, not for every surface).

/// Builds a `Glass` configuration.
func appGlass(tint: Color? = nil, interactive: Bool = false) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// Liquid Glass rounded card.
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(
            appGlass(tint: tint, interactive: interactive),
            in: .rect(cornerRadius: cornerRadius))
    }

    /// Liquid Glass capsule (pills, chips, panels).
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(appGlass(tint: tint, interactive: interactive), in: .capsule)
    }

    /// Liquid Glass circle (round icon buttons).
    func glassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(appGlass(tint: tint, interactive: interactive), in: .circle)
    }

    /// Inline navigation title set in the app font (the system title ignores Nunito).
    func appNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).appText(.titleMedium).foregroundStyle(AppPalette.onSurface)
                }
            }
    }

    /// Solid palette surface used for dense, editable content.
    func surfaceCard(
        cornerRadius: CGFloat = 20,
        fill: Color = AppPalette.surfaceVariant.opacity(0.55)
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Background

/// The app background: the Material `surfaceContainer` color with soft palette-colored light
/// behind the glass, so the Liquid Glass material has something to refract.
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppPalette.surfaceContainer
            GeometryReader { proxy in
                let side = max(proxy.size.width, proxy.size.height)
                ZStack {
                    Circle()
                        .fill(AppPalette.bgStar)
                        .frame(width: side * 0.9, height: side * 0.9)
                        .offset(x: proxy.size.width * 0.35, y: -side * 0.15)
                    Circle()
                        .fill(AppPalette.taskGradient(index: 0))
                        .opacity(0.16)
                        .frame(width: side * 0.7, height: side * 0.7)
                        .offset(x: -proxy.size.width * 0.45, y: proxy.size.height * 0.55)
                    Circle()
                        .fill(AppPalette.taskGradient(index: 3))
                        .opacity(0.12)
                        .frame(width: side * 0.5, height: side * 0.5)
                        .offset(x: proxy.size.width * 0.4, y: proxy.size.height * 0.85)
                }
                .blur(radius: 70)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Task icon

/// The task icon shown on the home card and the model page: a gradient circle with a white
/// glyph (Android `TaskIcon`, task index 0 = circle shape).
struct TaskIconView: View {
    var systemName: String = "receipt"
    var index: Int = 0
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(AppPalette.taskGradient(index: index))
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// Primary action button (Material filled `Button`): prominent tinted glass.
struct PrimaryActionLabel: View {
    let title: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title).appText(.titleMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
