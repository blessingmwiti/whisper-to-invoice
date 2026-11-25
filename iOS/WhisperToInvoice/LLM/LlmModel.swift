import Foundation

/// Inference accelerator (Android: `Accelerator`). Only CPU and GPU exist on iOS.
enum Accelerator: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case gpu
    case cpu

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// User-tunable inference settings (Android: the model's `configValues`).
struct LlmConfig: Equatable, Hashable, Sendable {
    var maxTokens: Int
    var topK: Int
    var topP: Double
    var temperature: Double
    var accelerator: Accelerator

    static let maxTokensRange: ClosedRange<Double> = 2000...8000
    static let topKRange: ClosedRange<Double> = 5...100
    static let topPRange: ClosedRange<Double> = 0...1
    static let temperatureRange: ClosedRange<Double> = 0...2
}

/// A downloadable on-device model. Port of the Android `Model` for the single model the app ships.
struct LlmModel: Identifiable, Hashable, Sendable {
    let name: String
    let modelId: String
    let modelFile: String
    let commitHash: String
    let info: String
    let sizeInBytes: Int64
    let minDeviceMemoryInGb: Int
    let defaultConfig: LlmConfig
    let supportedAccelerators: [Accelerator]

    var id: String { name }

    /// `https://huggingface.co/<modelId>/resolve/<commit>/<file>?download=true`
    var downloadURL: URL {
        // The components are compile-time constants, so this URL is always valid.
        URL(string: "https://huggingface.co/\(modelId)/resolve/\(commitHash)/\(modelFile)?download=true")!
    }

    var learnMoreURL: URL { URL(string: "https://huggingface.co/\(modelId)")! }

    /// Path of the model file relative to the models directory. Includes the commit hash so a
    /// new model version never reuses a stale file.
    var relativePath: String { "\(commitHash)/\(modelFile)" }

    /// The model the app ships with (Android: `TEST_MODEL_ALLOW_LIST`).
    static let gemma4E2B = LlmModel(
        name: "Gemma-4-E2B-it",
        modelId: "litert-community/gemma-4-E2B-it-litert-lm",
        modelFile: "gemma-4-E2B-it.litertlm",
        commitHash: "7fa1d78473894f7e736a21d920c3aa80f950c0db",
        info: "Gemma 4 E2B — on-device multimodal model with audio support. Powers Whisper to Invoice.",
        sizeInBytes: 2_583_085_056,
        minDeviceMemoryInGb: 4,
        defaultConfig: LlmConfig(
            maxTokens: 2048, topK: 64, topP: 0.95, temperature: 0.2, accelerator: .gpu),
        supportedAccelerators: [.gpu, .cpu])

    static let all: [LlmModel] = [.gemma4E2B]
}
