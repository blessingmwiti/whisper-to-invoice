import SwiftUI

/// The accent used for task-related controls (Android: `getTaskBgGradientColors(task)[1]`).
private var taskAccent: Color { AppPalette.taskBgGradientColors(index: 0)[1] }

// MARK: - Model card

/// A model card (Android: `ModelItem`): name, status, expandable description and the
/// download / try-it control.
struct ModelItemView: View {
    @Environment(ModelManager.self) private var manager

    let model: LlmModel
    let onTryIt: () -> Void

    @State private var isExpanded: Bool
    @State private var showDeleteConfirmation = false

    init(model: LlmModel, defaultExpanded: Bool, onTryIt: @escaping () -> Void) {
        self.model = model
        self.onTryIt = onTryIt
        _isExpanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isExpanded, !model.info.isEmpty {
                MarkdownText(text: model.info, color: AppPalette.onSurfaceVariant)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
            DownloadAndTryButton(
                model: model,
                canShowTryIt: true,
                compact: !isExpanded,
                onTryIt: onTryIt)
                .padding(.top, isExpanded ? 8 : 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            withAnimation(.smooth(duration: 0.25)) { isExpanded.toggle() }
        }
        .alert("Delete download", isPresented: $showDeleteConfirmation) {
            Button("OK", role: .destructive) {
                Task { await manager.deleteModel() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete the downloaded model \"\(model.name)\"?")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .appText(.titleMedium)
                    .foregroundStyle(AppPalette.onSurface)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ModelStatusDetails(model: model)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.modelInfoIcon)
                    Link(destination: model.learnMoreURL) {
                        Text("Learn more and see model license")
                            .appText(.bodyMedium)
                            .foregroundStyle(AppPalette.link)
                            .underline()
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            Spacer(minLength: 8)
            if manager.downloadStatus == .succeeded {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppPalette.onSurfaceVariant.opacity(0.8))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.onSurfaceVariant.opacity(0.6))
                .padding(.top, 10)
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
        }
    }
}

// MARK: - Status

/// Status icon + size / progress text (Android: `ModelStatusDetails`).
struct ModelStatusDetails: View {
    @Environment(ModelManager.self) private var manager
    let model: LlmModel

    var body: some View {
        HStack(spacing: 4) {
            StatusIcon(status: manager.downloadStatus)
            if case .failed(let message) = manager.downloadStatus {
                Text(message)
                    .appText(.labelSmall)
                    .tracking(0)
                    .foregroundStyle(AppPalette.error)
                    .lineLimit(3)
            } else {
                Text(label)
                    .appText(.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.onSurfaceVariant)
                    .lineLimit(1)
            }
        }
    }

    private var label: String {
        switch manager.downloadStatus {
        case .inProgress(let received, let total, let bytesPerSecond):
            return progressLabel(received: received, total: total, bytesPerSecond: bytesPerSecond, paused: false)
        case .partiallyDownloaded(let received, let total):
            return progressLabel(received: received, total: total, bytesPerSecond: 0, paused: true)
        default:
            return Fmt.humanReadableSize(model.sizeInBytes)
        }
    }

    private func progressLabel(received: Int64, total: Int64, bytesPerSecond: Int64, paused: Bool) -> String {
        let totalSize = total == 0 ? model.sizeInBytes : total
        var text = "\(Fmt.humanReadableSize(received, extraDecimalForGbAndAbove: true)) of \(Fmt.humanReadableSize(totalSize))"
        if bytesPerSecond > 0 { text += " · \(Fmt.humanReadableSize(bytesPerSecond)) / s" }
        if paused { text += " · paused" }
        return text
    }
}

/// Download state icon (Android: `StatusIcon`).
struct StatusIcon: View {
    let status: ModelDownloadStatus

    var body: some View {
        switch status {
        case .notDownloaded:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(AppPalette.modelInfoIcon)
                .accessibilityLabel("Not downloaded")
        case .succeeded:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(taskAccent)
                .accessibilityLabel("Downloaded")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(argb: 0xFFAA0000))
                .accessibilityLabel("Download failed")
        case .inProgress, .partiallyDownloaded:
            Image(systemName: "arrow.down.circle.dotted")
                .foregroundStyle(AppPalette.onSurface)
                .accessibilityLabel("Downloading")
        }
    }
}

// MARK: - Progress bar

/// A rounded download progress bar: dim track, accent fill that animates smoothly and is
/// always at least a small sliver wide once the download has started.
struct DownloadProgressBar: View {
    let progress: Double
    let tint: Color

    private let height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let fraction = min(max(progress, 0), 1)
            let fillWidth = fraction > 0 ? max(height, proxy.size.width * fraction) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(AppPalette.onSurface.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillWidth)
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.smooth(duration: 0.4), value: fraction)
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Download progress")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }
}

// MARK: - Download / try-it button

/// Handles "Download", the in-progress capsule and "Try it" (Android: `DownloadAndTryButton`).
struct DownloadAndTryButton: View {
    @Environment(ModelManager.self) private var manager

    let model: LlmModel
    var canShowTryIt = true
    var compact = false
    let onTryIt: () -> Void

    @State private var checkingAccess = false
    @State private var showMemoryWarning = false
    @State private var showNetworkError = false
    @State private var httpErrorStatus: Int?

    private var status: ModelDownloadStatus { manager.downloadStatus }

    private var needToDownloadFirst: Bool {
        switch status {
        case .notDownloaded, .failed, .partiallyDownloaded: true
        default: false
        }
    }

    private var isDownloading: Bool {
        if case .inProgress = status { return true }
        return false
    }

    private var progress: Double {
        switch status {
        case .inProgress(let received, let total, _):
            guard total > 0 else { return 0 }
            return min(max(Double(received) / Double(total), 0), 1)
        default:
            return 0
        }
    }

    var body: some View {
        Group {
            if isDownloading || checkingAccess {
                progressCapsule
            } else if !needToDownloadFirst && !canShowTryIt {
                EmptyView()
            } else {
                actionButton
            }
        }
        .alert("Memory Warning", isPresented: $showMemoryWarning) {
            Button("Proceed anyway") { beginDownload() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The model you've selected may exceed your device's memory, which can cause the app to crash. For the best experience, we recommend trying a smaller model.")
        }
        .alert("Unknown network error", isPresented: $showNetworkError) {
            Button("Close", role: .cancel) {}
        } message: {
            if let httpErrorStatus {
                Text("The server answered with HTTP \(httpErrorStatus). Please try again later.")
            } else {
                Text("Please check your internet connection.")
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        let label = HStack(spacing: 8) {
            Image(systemName: needToDownloadFirst ? "arrow.down.to.line" : "arrow.right")
            if !compact {
                Text(needToDownloadFirst ? "Download" : "Try it").appText(.titleMedium)
            }
        }
        .frame(maxWidth: compact ? nil : .infinity)
        .frame(minHeight: 30)

        if needToDownloadFirst {
            Button(action: handleTap) { label }
                .buttonStyle(.glass)
                .tint(AppPalette.onSurface)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("Download")
        } else {
            Button(action: handleTap) { label }
                .buttonStyle(.glassProminent)
                .tint(taskAccent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("Try it")
        }
    }

    private var progressCapsule: some View {
        HStack(spacing: 8) {
            if checkingAccess {
                Text("Checking access...")
                    .appText(.bodyMedium)
                    .foregroundStyle(AppPalette.onSurface)
                    .frame(maxWidth: .infinity)
            } else {
                Text(percentLabel)
                    .appText(.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.onSurface)
                    .frame(width: 44, alignment: .leading)
                DownloadProgressBar(progress: progress, tint: taskAccent)
                Button {
                    manager.cancelDownload()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Stop")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .glassCapsule()
    }

    /// Whole percent; "<1%" while a download has started but is under one percent.
    private var percentLabel: String {
        let percent = Int(progress * 100)
        return percent == 0 && progress > 0 ? "<1%" : "\(percent)%"
    }

    private func handleTap() {
        guard needToDownloadFirst else {
            onTryIt()
            return
        }
        if manager.isMemoryLow {
            showMemoryWarning = true
        } else {
            beginDownload()
        }
    }

    private func beginDownload() {
        checkingAccess = true
        Task {
            let result = await manager.preflightDownload()
            checkingAccess = false
            switch result {
            case .ok:
                manager.startDownload()
            case .networkError:
                httpErrorStatus = nil
                showNetworkError = true
            case .httpError(let code):
                httpErrorStatus = code
                showNetworkError = true
            }
        }
    }
}
