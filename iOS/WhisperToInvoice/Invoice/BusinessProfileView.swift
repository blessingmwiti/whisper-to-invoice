import PhotosUI
import SwiftUI

/// The business profile editor (Android: `BusinessProfileScreen`).
struct BusinessProfileView: View {
    @Environment(InvoiceServices.self) private var services

    @State private var profile = BusinessProfile()
    @State private var logo: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Logo")
                logoPicker

                SectionLabel(text: "Business Details")
                LabeledTextField(
                    title: "Business name *",
                    text: $profile.businessName,
                    placeholder: "e.g. Acme General Store",
                    capitalization: .words)
                LabeledTextField(
                    title: "Tagline (optional)",
                    text: $profile.tagline,
                    placeholder: "e.g. Quality goods, fair prices")

                SectionLabel(text: "Contact")
                LabeledTextField(
                    title: "Address",
                    text: $profile.address,
                    placeholder: "e.g. 123 Main Street, Springfield",
                    axis: .vertical,
                    lineLimit: 2...3,
                    capitalization: .words)
                LabeledTextField(
                    title: "Phone",
                    text: $profile.phone,
                    placeholder: "e.g. +254 712 345 678",
                    keyboard: .phonePad,
                    capitalization: .never)
                LabeledTextField(
                    title: "Email (optional)",
                    text: $profile.email,
                    placeholder: "e.g. store@example.com",
                    keyboard: .emailAddress,
                    capitalization: .never)

                SectionLabel(text: "Payment Instructions")
                LabeledTextField(
                    title: "Payment details",
                    text: $profile.paymentInstructions,
                    placeholder: "e.g. M-Pesa: 0700 000 000 (John Doe)\nBank: First National Bank A/C: 1234567890",
                    axis: .vertical,
                    lineLimit: 3...6)

                Button(action: save) {
                    PrimaryActionLabel(title: "Save Profile", systemImage: nil)
                }
                .buttonStyle(.glass)
                .tint(AppPalette.primary)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .appNavigationTitle("Business Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: save) {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Save")
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .appText(.bodyMedium)
                    .foregroundStyle(AppPalette.onSurface)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassCapsule()
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.smooth, value: toast)
        .task { await load() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await importLogo(item) }
        }
    }

    // MARK: Logo

    private var logoPicker: some View {
        let currentLogo = logo
        return PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            LogoTile(logo: currentLogo)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(currentLogo == nil ? "Add logo" : "Change business logo")
    }

    // MARK: Actions

    private func load() async {
        let repository = services.profile
        let loaded = await Task.detached(priority: .userInitiated) {
            (repository.get(), repository.loadLogo())
        }.value
        profile = loaded.0
        logo = loaded.1
    }

    private func importLogo(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        let repository = services.profile
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                AppLog.profile.error("Picked item returned no data")
                show("Could not read the selected image")
                return
            }
            let path = try await Task.detached(priority: .userInitiated) {
                try repository.importLogo(from: data)
            }.value
            profile.logoPath = path
            logo = await Task.detached(priority: .userInitiated) { repository.loadLogo() }.value
        } catch {
            AppLog.profile.error("Logo import failed: \(error.localizedDescription, privacy: .public)")
            show(error.localizedDescription)
        }
    }

    private func save() {
        let repository = services.profile
        let snapshot = profile
        Task {
            await Task.detached(priority: .userInitiated) { repository.save(snapshot) }.value
            show("Profile saved")
        }
    }

    private func show(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { toast = nil }
        }
    }
}

/// The 96 pt logo tile (Android: `LogoPicker`): the stored logo, or an "Add logo" prompt.
private struct LogoTile: View {
    let logo: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.surfaceVariant.opacity(0.55))
            if let logo {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Business logo")
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28))
                    Text("Add logo").appText(.labelSmall)
                }
                .foregroundStyle(AppPalette.onSurfaceVariant)
            }
        }
        .frame(width: 96, height: 96)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppPalette.outlineVariant, lineWidth: 1)
        )
    }
}
