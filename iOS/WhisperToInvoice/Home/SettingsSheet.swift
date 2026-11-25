import SwiftUI

/// Settings (Android: `SettingsDialog`): theme, licenses, legal links.
struct SettingsSheet: View {
    @Environment(ThemeSettings.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let onOpenAbout: () -> Void
    let onOpenPrivacy: () -> Void
    let onOpenLicenses: () -> Void

    @State private var showTos = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings").appText(.titleLarge).foregroundStyle(AppPalette.onSurface)
                Text("App version: \(AppInfo.versionString)")
                    .appText(.labelSmall)
                    .foregroundStyle(AppPalette.onSurfaceVariant)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        subtitle("Theme")
                        Picker("Theme", selection: Binding(
                            get: { theme.themeOverride },
                            set: { theme.select($0) })
                        ) {
                            ForEach(ThemeOverride.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        subtitle("Third-party libraries")
                        Button("View licenses", action: onOpenLicenses)
                            .buttonStyle(.glass)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        subtitle("Terms of service")
                        Button("View App Terms of Service") { showTos = true }
                            .buttonStyle(.glass)
                        Button("Privacy Policy", action: onOpenPrivacy)
                            .buttonStyle(.glass)
                        Button("About & open source", action: onOpenAbout)
                            .buttonStyle(.glass)
                        ClickableLink(title: "Gemma Terms of Use", url: LegalConstants.gemmaTermsURL)
                            .padding(.top, 4)
                        ClickableLink(
                            title: "Gemma Prohibited Use Policy", url: LegalConstants.gemmaProhibitedUseURL)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                dismiss()
            } label: {
                PrimaryActionLabel(title: "Close", systemImage: nil)
            }
            .buttonStyle(.glassProminent)
            .tint(AppPalette.primary)
        }
        .padding(20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showTos) {
            AppTosView(viewingMode: true) { showTos = false }
        }
    }

    private func subtitle(_ text: String) -> some View {
        Text(text)
            .appText(.titleSmall, weight: .medium)
            .foregroundStyle(AppPalette.onSurface)
    }
}
