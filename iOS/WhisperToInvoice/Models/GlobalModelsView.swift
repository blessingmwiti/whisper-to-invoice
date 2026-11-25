import SwiftUI

/// The global model manager (Android: `GlobalModelManager`): all models, promo banner, close
/// button.
struct GlobalModelsView: View {
    @Environment(ModelManager.self) private var manager
    @Environment(AppPreferences.self) private var preferences
    @Binding var path: [Route]

    private static let promoId = "gm4_banner"
    @State private var showPromo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if showPromo {
                    PromoBannerView(onDismiss: {
                        withAnimation(.smooth) { showPromo = false }
                        preferences.addViewedPromo(Self.promoId)
                    })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ForEach(manager.models) { model in
                    ModelItemView(model: model, defaultExpanded: true) {
                        path.append(.model)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(AppPalette.onSurface)
                        .accessibilityHidden(true)
                    Text("Models (\(manager.models.count))").appText(.titleMedium)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if !path.isEmpty { path.removeLast() }
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
        .onAppear {
            showPromo = !preferences.hasViewedPromo(Self.promoId)
        }
    }
}

/// Promo banner (Android: `PromoBannerGm4`).
struct PromoBannerView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gemma 4: now available")
                .appText(.titleMedium)
                .foregroundStyle(AppPalette.onSurface)
            Text("Built from the same world-class technology as Gemini 3, Gemma 4 brings frontier intelligence to your mobile and edge devices.")
                .font(.app(size: 12, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(AppPalette.onSurface)
            HStack(spacing: 8) {
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.glass)
                if let url = URL(string: "https://ai.google.dev/gemma") {
                    Link("Read more", destination: url)
                        .buttonStyle(.glassProminent)
                        .tint(AppPalette.primary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        // The star is a square as tall as the banner, pinned to the trailing edge (Android parity).
        .background(alignment: .trailing) {
            GeometryReader { proxy in
                Image(systemName: "sparkle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppPalette.promoBannerIcon)
                    .frame(width: proxy.size.height, height: proxy.size.height)
                    .frame(width: proxy.size.width, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
        .background(AppPalette.promoBannerBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
