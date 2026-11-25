import SwiftUI

/// The home screen (Android: `HomeScreen` with `gm4 = false`): app title, intro and the single
/// "Whisper to Invoice" task card. The Android navigation drawer becomes a glass menu sheet.
struct HomeView: View {
    @Environment(AppPreferences.self) private var preferences
    @Binding var path: [Route]

    @State private var showMenu = false
    @State private var showSettings = false
    @State private var showTos = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                titleView
                Text(AppInfo.intro)
                    .appText(.bodyMedium)
                    .foregroundStyle(AppPalette.onSurface)
                    .padding(.bottom, 24)

                TaskCardView(index: 0, onTap: { path.append(.modelList) })
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Menu")
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image("LogoIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                    Text(AppInfo.name).appText(.titleMedium)
                }
            }
        }
        .sheet(isPresented: $showMenu) {
            HomeMenuSheet(
                onSettings: { showMenu = false; showSettings = true },
                onModels: { showMenu = false; path.append(.globalModels) },
                onInvoices: { showMenu = false; path.append(.invoiceList) },
                onProfile: { showMenu = false; path.append(.businessProfile) })
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                onOpenAbout: { showSettings = false; path.append(.about) },
                onOpenPrivacy: { showSettings = false; path.append(.privacy) },
                onOpenLicenses: { showSettings = false; path.append(.licenses) })
        }
        .sheet(isPresented: $showTos) {
            AppTosView {
                preferences.acceptTos()
                showTos = false
            }
        }
        .onAppear {
            if !preferences.isTosAccepted { showTos = true }
        }
    }

    /// "Whisper to" in the surface colour and "Invoice" in the title gradient
    /// (Android `AppTitle`).
    private var titleView: some View {
        VStack(alignment: .leading, spacing: -4) {
            Text("Whisper to")
                .font(.app(size: 44, weight: .medium, relativeTo: .largeTitle))
                .tracking(-1)
                .foregroundStyle(AppPalette.onSurface)
            Text("Invoice")
                .font(.app(size: 44, weight: .medium, relativeTo: .largeTitle))
                .tracking(-1)
                .foregroundStyle(
                    LinearGradient(
                        colors: AppPalette.appTitleGradient,
                        startPoint: .leading, endPoint: .trailing))
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppInfo.name)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The task card (Android: `TaskCard`, list variant): label, model count and the task icon, on
/// Liquid Glass.
struct TaskCardView: View {
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.taskLabel)
                        .appText(.titleMedium)
                        .foregroundStyle(AppPalette.onSurface)
                    Text("1 Model")
                        .appText(.bodyMedium)
                        .foregroundStyle(AppPalette.onSurfaceVariant)
                }
                Spacer()
                TaskIconView(index: index, size: 40)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .glassCard(cornerRadius: 24, interactive: true)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(AppInfo.taskLabel) task with 1 models")
    }
}

// MARK: - Menu

/// The menu (Android: navigation drawer) with four square tiles.
struct HomeMenuSheet: View {
    let onSettings: () -> Void
    let onModels: () -> Void
    let onInvoices: () -> Void
    let onProfile: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    MenuTile(
                        label: "Settings", description: "Manage application settings",
                        systemImage: "gearshape.fill", gradientIndex: 2, action: onSettings)
                    MenuTile(
                        label: "Models", description: "Browse, try, and benchmark models",
                        systemImage: "list.bullet.rectangle.fill", gradientIndex: 1, action: onModels)
                }
                GridRow {
                    MenuTile(
                        label: "My Invoices", description: "View saved invoices",
                        systemImage: "clock.arrow.circlepath", gradientIndex: 0, action: onInvoices)
                    MenuTile(
                        label: "Business Profile", description: "Name, logo, payment",
                        systemImage: "building.2.fill", gradientIndex: 3, action: onProfile)
                }
            }
        }
        .padding(16)
        .presentationDetents([.height(440), .large])
        .presentationDragIndicator(.visible)
    }
}

/// A square menu tile (Android: `SquareDrawerItem`).
struct MenuTile: View {
    let label: String
    let description: String
    let systemImage: String
    let gradientIndex: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(AppPalette.taskGradient(index: gradientIndex))
                    .frame(height: 40, alignment: .leading)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .appText(.bodyLarge, weight: .medium)
                        .foregroundStyle(AppPalette.onSurface)
                    Text(description)
                        .appText(.bodySmall)
                        .foregroundStyle(AppPalette.onSurfaceVariant)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1, contentMode: .fit)
            .glassCard(cornerRadius: 24, interactive: true)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
