import Foundation
import LiteRTLM

enum LlmHelperError: LocalizedError {
    case notInitialized
    case modelFileMissing

    var errorDescription: String? {
        switch self {
        case .notInitialized: "LlmModelInstance is not initialized."
        case .modelFileMissing: "The model file is missing. Please download the model again."
        }
    }
}

/// Wraps the LiteRT-LM `Engine` / `Conversation` for the single loaded model
/// (Android: `LlmChatModelHelper`).
///
/// All native calls happen inside this actor, i.e. off the main thread.
actor LlmChatModelHelper {
    private var engine: Engine?
    private var conversation: Conversation?
    private var loadedConfig: LlmConfig?

    var isInitialized: Bool { engine != nil && conversation != nil }

    /// Loads the model and creates the first conversation. Can take several seconds.
    func initialize(modelPath: String, config: LlmConfig) async throws {
        cleanUp()

        guard FileManager.default.fileExists(atPath: modelPath) else {
            AppLog.llm.error("Model file not found at the expected location")
            throw LlmHelperError.modelFileMissing
        }

        let backend: Backend = config.accelerator == .gpu ? .gpu : .cpu()
        AppLog.llm.info(
            """
            Initializing engine: backend=\(config.accelerator.rawValue, privacy: .public) \
            maxTokens=\(config.maxTokens, privacy: .public)
            """)
        InvoiceDiagnostics.logMemory("llm.initialize.begin")

        let engineConfig = try EngineConfig(
            modelPath: modelPath,
            backend: backend,
            visionBackend: nil,
            // The audio executor must run on CPU for Gemma audio input (same as Android).
            audioBackend: .cpu(),
            maxNumTokens: config.maxTokens,
            cacheDir: AppDirectories.engineCache.path)

        let newEngine = Engine(engineConfig: engineConfig)
        do {
            try await newEngine.initialize()
            let newConversation = try await newEngine.createConversation(
                with: try Self.makeConversationConfig(config))
            engine = newEngine
            conversation = newConversation
            loadedConfig = config
        } catch {
            AppLog.llm.error("Engine initialization failed: \(error.localizedDescription, privacy: .public)")
            InvoiceDiagnostics.logMemory("llm.initialize.failed")
            throw error
        }
        InvoiceDiagnostics.logMemory("llm.initialize.done")
        AppLog.llm.info("Engine initialized")
    }

    /// Replaces the conversation with a fresh one so no earlier audio or prompt stays in context.
    func resetConversation() async throws {
        guard let engine, let loadedConfig else { throw LlmHelperError.notInitialized }
        conversation = nil
        conversation = try await engine.createConversation(
            with: try Self.makeConversationConfig(loadedConfig))
        AppLog.llm.info("Conversation reset")
    }

    /// Sends the audio clip and prompt and streams the model's text output. Each element is a new
    /// chunk of text (not the accumulated text).
    func infer(wavData: Data, prompt: String) throws -> AsyncThrowingStream<String, Error> {
        guard let conversation else { throw LlmHelperError.notInitialized }

        AppLog.llm.info("Inference started: audioBytes=\(wavData.count, privacy: .public) promptChars=\(prompt.count, privacy: .public)")

        return AsyncThrowingStream<String, Error> { continuation in
            // `Message` and its stream are not `Sendable`, so they are created and consumed
            // entirely inside this task. Only `Data`, `String` and `Conversation` cross over.
            let task = Task.detached {
                do {
                    // Audio first, then the text, so the last token is the instruction (same as Android).
                    var contents: [Content] = [.audioData(wavData)]
                    if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        contents.append(.text(prompt))
                    }
                    let message = Message(contents: contents, role: .user)
                    for try await chunk in conversation.sendMessageStream(message) {
                        let text = chunk.toString
                        if !text.isEmpty { continuation.yield(text) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Cancels the running inference (Android: `stopResponse`).
    func stopResponse() {
        guard let conversation else { return }
        do {
            try conversation.cancel()
            AppLog.llm.info("Inference cancel requested")
        } catch {
            AppLog.llm.error("Cancel failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Releases the engine and its memory.
    func cleanUp() {
        guard engine != nil || conversation != nil else { return }
        conversation = nil
        engine = nil
        loadedConfig = nil
        AppLog.llm.info("Engine released")
        InvoiceDiagnostics.logMemory("llm.cleanUp")
    }

    private static func makeConversationConfig(_ config: LlmConfig) throws -> ConversationConfig {
        let sampler = try SamplerConfig(
            topK: config.topK,
            topP: Float(config.topP),
            temperature: Float(config.temperature))
        return ConversationConfig(samplerConfig: sampler)
    }
}
