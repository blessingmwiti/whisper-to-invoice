import SwiftUI

/// The task screen of the model (Android: `CustomTaskScreen`): the download panel until the model
/// is on the device, then the invoice flow. The model is initialised on entry and released on exit.
struct ModelPageView: View {
    @Environment(ModelManager.self) private var manager
    @Binding var path: [Route]

    @State private var showConfig = false
    @State private var showInitError = false

    private var isInitializing: Bool { manager.initStatus == .initializing }
    private var isDownloaded: Bool { manager.downloadStatus == .succeeded }

    var body: some View {
        ZStack {
            AppBackground()
            if isDownloaded {
                InvoiceExtractionScreen()
            } else {
                ModelDownloadStatusPanel()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isInitializing)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image(systemName: "receipt")
                        .foregroundStyle(AppPalette.onSurface)
                        .accessibilityHidden(true)
                    Text(AppInfo.taskLabel).appText(.titleMedium)
                }
            }
            if isDownloaded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConfig = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .disabled(manager.initStatus != .initialized)
                    .accessibilityLabel("Model settings")
                }
            }
        }
        .task(id: manager.downloadStatus) {
            if manager.downloadStatus == .succeeded {
                AppLog.modelManager.info("Initializing model from the model page")
                manager.initializeModel()
            }
        }
        .onChange(of: manager.initStatus) { _, status in
            if case .error = status { showInitError = true }
        }
        .onDisappear {
            manager.cleanUpModel()
        }
        .sheet(isPresented: $showConfig) {
            ConfigSheet(
                initial: manager.config,
                defaults: manager.model.defaultConfig,
                accelerators: manager.model.supportedAccelerators
            ) { newConfig in
                manager.updateConfig(newConfig)
            }
        }
        .alert("Error", isPresented: $showInitError) {
            Button("Close") {
                if !path.isEmpty { path.removeLast() }
            }
        } message: {
            if case .error(let message) = manager.initStatus {
                Text(message)
            }
        }
    }
}

// MARK: - Download panel

/// Shown while the model is not downloaded (Android: `ModelDownloadStatusInfoPanel`).
struct ModelDownloadStatusPanel: View {
    @Environment(ModelManager.self) private var manager

    private var isDownloading: Bool {
        switch manager.downloadStatus {
        case .inProgress, .partiallyDownloaded: true
        default: false
        }
    }

    var body: some View {
        VStack {
            Spacer()
            if isDownloading {
                DownloadingBadge()
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            DownloadAndTryButton(model: manager.model, canShowTryIt: false, onTryIt: {})
                .padding(.horizontal, 32)
                .padding(.top, 4)
                .padding(.bottom, 16)
            Group {
                if isDownloading {
                    Text("Feel free to switch apps or lock your device.\nThe download will continue in the background.\nWe'll send a notification when it's done.")
                        .appText(.bodyLarge)
                        .foregroundStyle(AppPalette.onSurface)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            Spacer()
        }
        .animation(.smooth, value: isDownloading)
    }
}

/// The animated glyph above the progress bar.
private struct DownloadingBadge: View {
    var body: some View {
        Image(systemName: "arrow.down.circle")
            .font(.system(size: 56, weight: .light))
            .foregroundStyle(AppPalette.taskGradient(index: 0))
            .symbolEffect(.pulse)
            .frame(width: 120, height: 120)
            .glassCircle()
            .accessibilityHidden(true)
    }
}

// MARK: - Config sheet

/// Model settings (Android: `ConfigDialog` titled "Configurations").
struct ConfigSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initial: LlmConfig
    let defaults: LlmConfig
    let accelerators: [Accelerator]
    let onApply: (LlmConfig) -> Void

    @State private var draft: LlmConfig

    init(
        initial: LlmConfig, defaults: LlmConfig, accelerators: [Accelerator],
        onApply: @escaping (LlmConfig) -> Void
    ) {
        self.initial = initial
        self.defaults = defaults
        self.accelerators = accelerators
        self.onApply = onApply
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurations").appText(.titleLarge).foregroundStyle(AppPalette.onSurface)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SliderRow(
                        title: "Max tokens",
                        value: Binding(
                            get: { Double(draft.maxTokens) },
                            set: { draft.maxTokens = Int($0.rounded()) }),
                        range: LlmConfig.maxTokensRange, step: 1, format: { String(Int($0)) })
                    SliderRow(
                        title: "TopK",
                        value: Binding(
                            get: { Double(draft.topK) },
                            set: { draft.topK = Int($0.rounded()) }),
                        range: LlmConfig.topKRange, step: 1, format: { String(Int($0)) })
                    SliderRow(
                        title: "TopP",
                        value: $draft.topP,
                        range: LlmConfig.topPRange, step: 0.01, format: { String(format: "%.2f", $0) })
                    SliderRow(
                        title: "Temperature",
                        value: $draft.temperature,
                        range: LlmConfig.temperatureRange, step: 0.01, format: { String(format: "%.2f", $0) })

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accelerator")
                            .appText(.titleSmall)
                            .foregroundStyle(AppPalette.onSurface)
                        Picker("Accelerator", selection: $draft.accelerator) {
                            ForEach(accelerators) { accelerator in
                                Text(accelerator.label).tag(accelerator)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            HStack {
                Button("Restore default") { draft = defaults }
                    .buttonStyle(.glass)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glass)
                Button("OK") {
                    onApply(draft)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(AppPalette.primary)
            }
        }
        .padding(20)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).appText(.titleSmall).foregroundStyle(AppPalette.onSurface)
                Spacer()
                Text(format(value))
                    .appText(.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.onSurfaceVariant)
            }
            Slider(value: $value, in: range, step: step)
                .tint(AppPalette.primary)
                .accessibilityLabel(title)
                .accessibilityValue(format(value))
        }
    }
}
