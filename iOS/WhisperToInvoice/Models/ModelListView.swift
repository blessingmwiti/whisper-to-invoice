import SwiftUI

/// The model list of the task (Android: `ModelManager` + `ModelList`).
struct ModelListView: View {
    @Environment(ModelManager.self) private var manager
    @Binding var path: [Route]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                Text("Recommended models")
                    .appText(.labelLarge)
                    .foregroundStyle(AppPalette.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .accessibilityAddTraits(.isHeader)
                ForEach(manager.models) { model in
                    ModelItemView(model: model, defaultExpanded: false) {
                        path.append(.model)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image(systemName: "receipt")
                        .foregroundStyle(AppPalette.onSurface)
                        .accessibilityHidden(true)
                    Text(AppInfo.taskLabel).appText(.titleMedium)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            TaskIconView(index: 0, size: 64)
            Text(AppInfo.taskLabel)
                .appText(.headlineLarge, weight: .medium)
                .foregroundStyle(
                    LinearGradient(
                        colors: AppPalette.taskBgGradientColors(index: 0),
                        startPoint: .leading, endPoint: .trailing)
                )
                .multilineTextAlignment(.center)
            Text(AppInfo.taskDescription)
                .appText(.bodyLarge)
                .tracking(0.2)
                .foregroundStyle(AppPalette.onSurface)
                .multilineTextAlignment(.center)
            Text("\(manager.models.count) \(manager.models.count == 1 ? "model" : "models") available")
                .appText(.bodyMedium)
                .foregroundStyle(AppPalette.onSurface.opacity(0.6))
        }
        .padding(.top, 32)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }
}
