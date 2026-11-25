import Observation
import SwiftUI

/// Terms and promo flags stored locally (Android: `TosViewModel` / data store).
@MainActor
@Observable
final class AppPreferences {
    private enum Key {
        static let tosAccepted = "tos_accepted"
        static let viewedPromoIds = "viewed_promo_ids"
    }

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var isTosAccepted: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isTosAccepted = defaults.bool(forKey: Key.tosAccepted)
    }

    func acceptTos() {
        defaults.set(true, forKey: Key.tosAccepted)
        isTosAccepted = true
    }

    func hasViewedPromo(_ id: String) -> Bool {
        (defaults.stringArray(forKey: Key.viewedPromoIds) ?? []).contains(id)
    }

    func addViewedPromo(_ id: String) {
        var ids = defaults.stringArray(forKey: Key.viewedPromoIds) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        defaults.set(ids, forKey: Key.viewedPromoIds)
    }
}

// MARK: - Terms of service

/// The Terms of Service sheet shown on first launch (Android: `AppTosDialog`).
struct AppTosView: View {
    var viewingMode = false
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LegalText.tosTitleApp)
                .appText(.headlineSmall, weight: .medium)
                .foregroundStyle(AppPalette.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MarkdownText(text: LegalText.tosBody, color: AppPalette.onSurfaceVariant)
                    MarkdownText(text: LegalText.tosGemmaNotice, color: AppPalette.onSurfaceVariant)
                }
                .padding(.top, 16)
            }

            Button(action: onDone) {
                PrimaryActionLabel(title: viewingMode ? "Close" : LegalText.tosAcceptButton, systemImage: nil)
            }
            .buttonStyle(.glassProminent)
            .tint(AppPalette.primary)
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.large])
        .interactiveDismissDisabled(!viewingMode)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("App")
                Text(LegalText.aboutAppDescription)
                    .appText(.bodyMedium)
                    .foregroundStyle(AppPalette.onSurfaceVariant)
                Text("Developer: \(LegalConstants.developerName) · \(LegalConstants.developerLocation)")
                    .appText(.bodyMedium)
                ClickableLink(
                    title: LegalConstants.developerEmail,
                    url: "mailto:\(LegalConstants.developerEmail)",
                    systemImage: "envelope")

                sectionTitle("Privacy")
                MarkdownText(text: LegalText.aboutPrivacySummary, color: AppPalette.onSurfaceVariant)
                ClickableLink(title: "Open full Privacy Policy", url: LegalConstants.privacyPolicyURL)

                sectionTitle("Open source")
                MarkdownText(text: LegalText.aboutOpenSourceNotice, color: AppPalette.onSurfaceVariant)
                ClickableLink(title: "View upstream source (AI Edge Gallery)", url: LegalConstants.upstreamSourceURL)
                ClickableLink(title: "Apache License 2.0", url: LegalConstants.apacheLicenseURL)
                ClickableLink(title: "Gemma Terms of Use", url: LegalConstants.gemmaTermsURL)
                NavigationLink(value: Route.licenses) {
                    Text("View third-party library licenses")
                        .appText(.titleMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)

                sectionTitle("AI disclosure")
                MarkdownText(text: LegalText.aboutAIDisclosure, color: AppPalette.onSurfaceVariant)
                ClickableLink(title: "Gemma Prohibited Use Policy", url: LegalConstants.gemmaProhibitedUseURL)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .appNavigationTitle("About")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .appText(.titleMedium, weight: .semiBold)
            .foregroundStyle(AppPalette.onSurface)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Privacy policy

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Privacy Policy · \(LegalConstants.developerName)")
                    .appText(.labelMedium)
                    .foregroundStyle(AppPalette.onSurfaceVariant)
                    .padding(.bottom, 16)
                MarkdownText(text: LegalText.privacyPolicyBody)
                ClickableLink(
                    title: LegalConstants.developerEmail,
                    url: "mailto:\(LegalConstants.developerEmail)",
                    systemImage: "envelope")
                    .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .appNavigationTitle("Privacy Policy")
    }
}

// MARK: - Third-party licenses

/// Third-party components shipped in the app (Android shows Google's OSS licenses screen).
struct LicensesView: View {
    private struct Entry: Identifiable {
        let name: String
        let license: String
        let url: String
        var id: String { name }
    }

    private let entries = [
        Entry(
            name: "LiteRT-LM (Google AI Edge)",
            license: "Apache License 2.0",
            url: "https://github.com/google-ai-edge/LiteRT-LM"),
        Entry(
            name: "Google AI Edge Gallery (upstream project)",
            license: "Apache License 2.0",
            url: LegalConstants.upstreamSourceURL),
        Entry(
            name: "Nunito font",
            license: "SIL Open Font License 1.1",
            url: "https://github.com/googlefonts/nunito"),
        Entry(
            name: "Gemma models",
            license: "Gemma Terms of Use",
            url: LegalConstants.gemmaTermsURL),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.name).appText(.titleMedium).foregroundStyle(AppPalette.onSurface)
                        Text(entry.license).appText(.bodyMedium).foregroundStyle(AppPalette.onSurfaceVariant)
                        ClickableLink(title: entry.url, url: entry.url)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 20)
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .appNavigationTitle("Third-party libraries")
    }
}
