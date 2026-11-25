import SwiftUI
import UIKit

/// The invoice flow (Android: `InvoiceExtractionScreen`): record → processing → editable result →
/// PDF → share.
struct InvoiceExtractionScreen: View {
    @Environment(ModelManager.self) private var manager
    @Environment(InvoiceServices.self) private var services
    @State private var viewModel: InvoiceExtractionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                InvoiceFlowContent(viewModel: viewModel)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InvoiceExtractionViewModel(
                    modelManager: manager,
                    repository: services.invoices,
                    profileRepository: services.profile)
            }
        }
        .onDisappear {
            viewModel?.cancelExtraction()
        }
    }
}

private struct InvoiceFlowContent: View {
    @Bindable var viewModel: InvoiceExtractionViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                IdleContent(viewModel: viewModel)
            case .processing:
                ProcessingContent()
            case .done, .saved:
                if viewModel.invoice != nil {
                    InvoiceResultView(viewModel: viewModel)
                }
            case .saving:
                SavingContent()
            case .error:
                ErrorContent(error: viewModel.error, onRetry: { viewModel.reset() })
            }
        }
        .animation(.smooth(duration: 0.25), value: viewModel.state)
    }
}

// MARK: - Idle

private struct IdleContent: View {
    @Environment(\.scenePhase) private var scenePhase
    let viewModel: InvoiceExtractionViewModel

    @State private var recorder = AudioRecorder()
    @State private var micGranted = AudioRecorder.hasMicrophonePermission
    @State private var micDenied = AudioRecorder.isMicrophonePermissionDenied
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Whisper to Invoice")
                .appText(.headlineSmall, weight: .bold)
                .foregroundStyle(AppPalette.onSurface)
            Text("Speak your sale — Gemma 4 will build the invoice")
                .appText(.bodyMedium)
                .foregroundStyle(AppPalette.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Text("Any language · Mix languages too ✓")
                .appText(.labelSmall)
                .foregroundStyle(AppPalette.primary)
                .padding(.top, 8)

            Group {
                if micGranted {
                    RecorderPanel(recorder: recorder, onToggle: toggleRecording, onClose: { recorder.cancel() })
                } else {
                    permissionPanel
                }
            }
            .padding(.top, 40)

            if let message = errorMessage ?? recorder.interruptionMessage {
                Text(message)
                    .appText(.bodySmall)
                    .foregroundStyle(AppPalette.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            Text("Example: \"Niliuza John nyanya kilo tatu, bei mia moja kila kilo, na vitunguu viwili mia tano\"")
                .appText(.bodySmall)
                .foregroundStyle(AppPalette.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .padding(.horizontal, 16)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .task {
            recorder.onMaxDurationReached = { data in submit(data) }
            AppLog.invoiceScreen.info("IdleContent entered. micPermissionGranted=\(micGranted, privacy: .public)")
            InvoiceDiagnostics.startPreviousExitReporting()
            var elapsed = 0
            while !Task.isCancelled {
                InvoiceDiagnostics.logMemory("idle-heartbeat t=\(elapsed)s")
                try? await Task.sleep(for: .seconds(5))
                elapsed += 5
            }
        }
        .onChange(of: scenePhase) { _, phase in
            AppLog.invoiceScreen.info("Lifecycle event: \(String(describing: phase), privacy: .public)")
            InvoiceDiagnostics.logMemory("lifecycle-\(String(describing: phase))")
            if phase != .active, recorder.isRecording {
                // Never keep the microphone open once the app leaves the foreground.
                recorder.cancel()
            }
            if phase == .active {
                micGranted = AudioRecorder.hasMicrophonePermission
                micDenied = AudioRecorder.isMicrophonePermissionDenied
            }
        }
        .onDisappear {
            AppLog.invoiceScreen.info("IdleContent disposed (screen left or app is closing)")
            if recorder.isRecording { recorder.cancel() }
        }
    }

    private var permissionPanel: some View {
        VStack(spacing: 8) {
            if micDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                        .appText(.titleMedium)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(AppPalette.primary)
            } else {
                Button {
                    Task {
                        micGranted = await AudioRecorder.requestMicrophonePermission()
                        micDenied = AudioRecorder.isMicrophonePermissionDenied
                    }
                } label: {
                    Label("Allow microphone access", systemImage: "mic.fill")
                        .appText(.titleMedium)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(AppPalette.primary)
            }
            Text("Microphone access is required to record your sale")
                .appText(.bodySmall)
                .foregroundStyle(AppPalette.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
    }

    private func toggleRecording() {
        errorMessage = nil
        if recorder.isRecording {
            submit(recorder.stop())
        } else {
            do {
                try recorder.start()
            } catch {
                AppLog.invoiceScreen.error("Could not start recording: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }

    private func submit(_ pcm: Data) {
        guard !pcm.isEmpty else {
            AppLog.invoiceScreen.warning("Recording was empty; nothing to extract")
            errorMessage = "No audio was captured. Please try again."
            return
        }
        viewModel.extractInvoice(pcmBytes: pcm)
    }
}

/// The recorder controls (Android: `AudioRecorderPanel`): close button, status capsule and the
/// record / send button.
private struct RecorderPanel: View {
    let recorder: AudioRecorder
    let onToggle: () -> Void
    let onClose: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassCircle(interactive: true)
                .accessibilityLabel("Close")

                HStack {
                    if recorder.isRecording {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AppPalette.recordButtonBg)
                                .frame(width: 8, height: 8)
                                .symbolEffect(.pulse)
                            Text(String(format: "%.1f s", recorder.elapsedSeconds))
                                .appText(.bodyLarge)
                                .monospacedDigit()
                                .foregroundStyle(AppPalette.onSurface)
                        }
                        .padding(.leading, 12)
                    } else {
                        Text("Tap the record button to start")
                            .appText(.labelMedium)
                            .foregroundStyle(AppPalette.onSurfaceVariant)
                            .padding(.leading, 12)
                    }
                    Spacer(minLength: 8)
                    Button(action: onToggle) {
                        Image(systemName: recorder.isRecording ? "arrow.up" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .glassCircle(tint: AppPalette.taskIconColor(index: 0), interactive: true)
                    .accessibilityLabel(recorder.isRecording ? "Send audio clip" : "Start recording")
                }
                .frame(height: 52)
                .padding(.trailing, 4)
                .glassCapsule()
            }
        }
    }
}

// MARK: - Processing / saving / error

private struct ProcessingContent: View {
    var body: some View {
        VStack(spacing: 0) {
            ProgressView()
                .controlSize(.large)
                .scaleEffect(1.4)
                .tint(AppPalette.primary)
                .frame(width: 56, height: 56)
            Text("Gemma 4 is reading your sale…")
                .appText(.bodyLarge)
                .foregroundStyle(AppPalette.onSurface)
                .padding(.top, 24)
            Text("This runs 100% on-device")
                .appText(.bodySmall)
                .foregroundStyle(AppPalette.onSurfaceVariant)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SavingContent: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(AppPalette.primary)
            Text("Generating PDF…")
                .appText(.bodyLarge)
                .foregroundStyle(AppPalette.onSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorContent: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Something went wrong")
                .appText(.titleMedium)
                .foregroundStyle(AppPalette.error)
            Text(error)
                .appText(.bodySmall)
                .foregroundStyle(AppPalette.onSurface)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text("Try again").appText(.titleMedium).padding(.horizontal, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(AppPalette.primary)
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
