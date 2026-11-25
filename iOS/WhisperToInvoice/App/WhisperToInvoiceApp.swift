import SwiftUI

@main
struct WhisperToInvoiceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var modelManager = ModelManager()
    @State private var themeSettings = ThemeSettings()
    @State private var preferences = AppPreferences()
    @State private var services = InvoiceServices()
    @State private var path: [Route] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                HomeView(path: $path)
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                    }
            }
            .environment(modelManager)
            .environment(themeSettings)
            .environment(preferences)
            .environment(services)
            .tint(AppPalette.primary)
            .preferredColorScheme(themeSettings.themeOverride.colorScheme)
            .task {
                AppLog.app.info("App started. version=\(AppInfo.versionString, privacy: .public)")
                InvoiceDiagnostics.startPreviousExitReporting()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .modelList: ModelListView(path: $path)
        case .model: ModelPageView(path: $path)
        case .globalModels: GlobalModelsView(path: $path)
        case .businessProfile: BusinessProfileView()
        case .invoiceList: InvoiceListView()
        case .about: AboutView()
        case .privacy: PrivacyPolicyView()
        case .licenses: LicensesView()
        }
    }
}
