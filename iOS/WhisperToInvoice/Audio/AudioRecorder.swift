import AVFAudio
import Foundation
import Observation
import os

/// Thread-safe sink for the audio tap. Converts every microphone buffer to 16 kHz mono PCM16 and
/// collects the bytes. Created per recording.
private final class PcmCollector: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let inputSampleRate: Double
    private let storage = OSAllocatedUnfairLock(initialState: Data())

    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioRecorderError.cannotConvertFormat
        }
        self.converter = converter
        self.outputFormat = outputFormat
        self.inputSampleRate = inputFormat.sampleRate
    }

    var byteCount: Int { storage.withLock { $0.count } }

    func takeAll() -> Data {
        storage.withLock { data in
            let copy = data
            data = Data()
            return copy
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let ratio = outputFormat.sampleRate / inputSampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        // The converter pulls the input once per call; then reports "no data now".
        nonisolated(unsafe) var supplied = false
        nonisolated(unsafe) let input = buffer
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, output.frameLength > 0, let channel = output.int16ChannelData else {
            if let conversionError {
                AppLog.recorder.error("Audio conversion error: \(conversionError.localizedDescription, privacy: .public)")
            }
            return
        }
        let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size
        let bytes = Data(bytes: channel[0], count: byteCount)
        storage.withLock { $0.append(bytes) }
    }
}

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case cannotConvertFormat
    case noInputAvailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Microphone access is required to record your sale."
        case .cannotConvertFormat: "The microphone format is not supported."
        case .noInputAvailable: "No microphone input is available."
        }
    }
}

/// Records 16 kHz mono PCM16 audio with a 30 second limit (Android: `AudioRecorderPanel` logic).
@MainActor
@Observable
final class AudioRecorder {
    /// Maximum clip length (Android: `MAX_AUDIO_CLIP_DURATION_SEC`).
    static let maxDurationSeconds: Double = 30
    private static let bytesPerSecond = Double(PcmWav.sampleRate * PcmWav.channels * PcmWav.bitsPerSample / 8)

    private(set) var isRecording = false
    private(set) var elapsedSeconds: Double = 0
    /// Set when a recording was cut short by the system (call, route change, ...).
    private(set) var interruptionMessage: String?

    /// Called with the PCM16 bytes when the maximum duration is reached.
    @ObservationIgnored var onMaxDurationReached: ((Data) -> Void)?

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var collector: PcmCollector?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    // MARK: - Permission

    static var hasMicrophonePermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    static var isMicrophonePermissionDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }

    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    func start() throws {
        guard Self.hasMicrophonePermission else { throw AudioRecorderError.permissionDenied }
        guard !isRecording else { return }
        interruptionMessage = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw AudioRecorderError.noInputAvailable
        }
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(PcmWav.sampleRate),
            channels: AVAudioChannelCount(PcmWav.channels),
            interleaved: true)
        else { throw AudioRecorderError.cannotConvertFormat }

        let collector = try PcmCollector(inputFormat: inputFormat, outputFormat: outputFormat)
        Self.installTap(on: engine.inputNode, format: inputFormat, collector: collector)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            AppLog.recorder.error("Engine start failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        self.engine = engine
        self.collector = collector
        elapsedSeconds = 0
        isRecording = true
        observeInterruptions()
        startTimer()
        AppLog.recorder.info(
            "Recording started: inputRate=\(inputFormat.sampleRate, privacy: .public) channels=\(inputFormat.channelCount, privacy: .public)")
    }

    /// The tap block runs on a real-time audio thread, so it is created in a nonisolated context
    /// (a closure created inside this main-actor class would otherwise be main-actor isolated).
    private nonisolated static func installTap(
        on node: AVAudioInputNode, format: AVAudioFormat, collector: PcmCollector
    ) {
        node.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            collector.append(buffer)
        }
    }

    /// Stops recording and returns the PCM16 bytes captured so far.
    @discardableResult
    func stop() -> Data {
        let data = teardown()
        AppLog.recorder.info("Recording stopped: \(data.count, privacy: .public) bytes (~\(Double(data.count) / Self.bytesPerSecond, privacy: .public)s)")
        return data
    }

    /// Stops recording and throws the audio away.
    func cancel() {
        let data = teardown()
        AppLog.recorder.info("Recording cancelled, discarded \(data.count, privacy: .public) bytes")
    }

    private func teardown() -> Data {
        timerTask?.cancel()
        timerTask = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        let data = collector?.takeAll() ?? Data()
        collector = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return data
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.isRecording, let collector = self.collector else { return }
                let seconds = Double(collector.byteCount) / Self.bytesPerSecond
                self.elapsedSeconds = min(seconds, Self.maxDurationSeconds)
                if seconds >= Self.maxDurationSeconds {
                    let data = self.stop()
                    AppLog.recorder.info("Maximum duration reached")
                    self.onMaxDurationReached?(data)
                    return
                }
            }
        }
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                if rawType == AVAudioSession.InterruptionType.began.rawValue {
                    AppLog.recorder.warning("Recording interrupted by the system")
                    self.cancel()
                    self.interruptionMessage = "Recording was interrupted. Please try again."
                }
            }
        }
        let configChange = center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                AppLog.recorder.warning("Audio route changed while recording")
                self.cancel()
                self.interruptionMessage = "The audio input changed. Please record again."
            }
        }
        observers = [interruption, configChange]
    }
}
