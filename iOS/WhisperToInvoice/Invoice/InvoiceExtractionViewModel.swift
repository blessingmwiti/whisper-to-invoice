import Foundation
import Observation

enum ExtractionState: Equatable {
    case idle  // waiting for the user to record
    case processing  // Gemma 4 is running
    case done  // invoice extracted, user can edit / save
    case saving  // generating PDF + saving
    case saved  // PDF ready, show the share button
    case error
}

/// Drives the record → extract → edit → PDF flow (Android: `InvoiceExtractionViewModel`).
@MainActor
@Observable
final class InvoiceExtractionViewModel {
    private(set) var state: ExtractionState = .idle
    /// Editable copy shown on the result screen.
    private(set) var invoice: InvoiceData?
    private(set) var error = ""
    /// Location of the generated PDF, set after `.saved`.
    private(set) var pdfURL: URL?
    private(set) var savedId = ""

    @ObservationIgnored private let modelManager: ModelManager
    @ObservationIgnored private let repository: InvoiceRepository
    @ObservationIgnored private let profileRepository: BusinessProfileRepository
    @ObservationIgnored private let pdfGenerator = InvoicePdfGenerator()
    @ObservationIgnored private var extractionTask: Task<Void, Never>?

    /// How long to wait for the model to finish loading before giving up (Android: 30 s).
    private static let modelWaitSeconds = 30.0

    init(
        modelManager: ModelManager,
        repository: InvoiceRepository,
        profileRepository: BusinessProfileRepository
    ) {
        self.modelManager = modelManager
        self.repository = repository
        self.profileRepository = profileRepository
    }

    // MARK: - Audio → Gemma 4 → invoice JSON

    func extractInvoice(pcmBytes: Data) {
        guard state == .idle || state == .error else {
            AppLog.invoiceViewModel.warning("extractInvoice ignored in state \(String(describing: self.state), privacy: .public)")
            return
        }
        AppLog.invoiceViewModel.info(
            "extractInvoice: pcmBytes=\(pcmBytes.count, privacy: .public) (~\(pcmBytes.count / (16_000 * 2), privacy: .public)s of audio)")
        InvoiceDiagnostics.logMemory("extract-start")
        state = .processing
        error = ""

        let manager = modelManager
        extractionTask = Task { [weak self] in
            // Wait for the model to be ready.
            var waited = 0.0
            while manager.initStatus != .initialized, waited < Self.modelWaitSeconds {
                if case .error = manager.initStatus { break }
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(200))
                waited += 0.2
            }
            guard manager.initStatus == .initialized else {
                AppLog.invoiceViewModel.error("Model not ready after \(waited, privacy: .public)s: \(String(describing: manager.initStatus), privacy: .public)")
                self?.fail("Model not ready. Try again.")
                return
            }
            await self?.runInference(pcmBytes: pcmBytes, helper: manager.helper)
        }
    }

    private func runInference(pcmBytes: Data, helper: LlmChatModelHelper) async {
        let today = InvoiceData.today()
        let prompt = InvoiceParser.buildPrompt(today: today)
        let wav = PcmWav.wrap(pcm: pcmBytes)
        let startedAt = Date()
        AppLog.invoiceViewModel.info("Starting inference: wavBytes=\(wav.count, privacy: .public) promptChars=\(prompt.count, privacy: .public)")
        InvoiceDiagnostics.logMemory("inference-start")

        var accumulated = ""
        do {
            // A fresh conversation per clip so earlier audio never leaks into this extraction.
            try await helper.resetConversation()
            let stream = try await helper.infer(wavData: wav, prompt: prompt)
            for try await chunk in stream {
                if Task.isCancelled { break }
                accumulated += chunk
            }
        } catch {
            if Task.isCancelled { return }
            let elapsed = Date().timeIntervalSince(startedAt)
            AppLog.invoiceViewModel.error("Inference error after \(elapsed, privacy: .public)s: \(error.localizedDescription, privacy: .public)")
            InvoiceDiagnostics.logMemory("inference-error")
            fail("Error: \(error.localizedDescription)")
            return
        }
        if Task.isCancelled { return }

        let elapsed = Date().timeIntervalSince(startedAt)
        AppLog.invoiceViewModel.info("Inference done in \(elapsed, privacy: .public)s, responseChars=\(accumulated.count, privacy: .public)")
        InvoiceDiagnostics.logMemory("inference-done")
        let raw = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        // The raw output can contain client names and amounts, so it is logged as private.
        AppLog.invoiceViewModel.debug("Gemma raw: \(raw, privacy: .private)")
        invoice = InvoiceParser.parse(raw: raw, today: today)
        state = .done
    }

    private func fail(_ message: String) {
        error = message
        state = .error
    }

    /// Stops a running extraction and returns to the idle screen.
    func cancelExtraction() {
        extractionTask?.cancel()
        extractionTask = nil
        if state == .processing {
            let helper = modelManager.helper
            Task { await helper.stopResponse() }
            state = .idle
        }
    }

    // MARK: - User edits

    func updateClient(_ name: String) { mutate { $0.clientName = name } }
    func updateDate(_ date: String) { mutate { $0.date = date } }
    func updateNotes(_ notes: String) { mutate { $0.notes = notes } }
    func updateCurrency(_ currency: String) { mutate { $0.currency = currency } }

    func updateItem(at index: Int, _ item: InvoiceLineItem) {
        mutate { invoice in
            guard invoice.items.indices.contains(index) else { return }
            invoice.items[index] = item
            invoice.recalculateTotals()
        }
    }

    func addItem() {
        mutate { $0.items.append(InvoiceLineItem(description: "", qty: 1.0, unitPrice: 0.0, total: 0.0)) }
    }

    func removeItem(at index: Int) {
        mutate { invoice in
            guard invoice.items.indices.contains(index) else { return }
            invoice.items.remove(at: index)
            invoice.recalculateTotals()
        }
    }

    /// `percent` is a rate like 16.0, meaning 16%. Recomputes the tax amount and the total.
    func updateTaxPercent(_ percent: Double) {
        mutate { invoice in
            invoice.taxPercent = percent
            invoice.tax = invoice.subtotal * percent / 100.0
            invoice.total = invoice.subtotal + invoice.tax
        }
    }

    private func mutate(_ transform: (inout InvoiceData) -> Void) {
        guard var current = invoice else { return }
        transform(&current)
        invoice = current
    }

    // MARK: - Save + PDF

    func saveAndGeneratePdf() {
        guard let invoice, state == .done || state == .saved else { return }
        let previousId = savedId
        state = .saving

        let repository = self.repository
        let profileRepository = self.profileRepository
        let generator = self.pdfGenerator
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { () -> (String, URL) in
                    let profile = profileRepository.get()
                    let logo = profile.logoPath.isEmpty ? nil : profileRepository.loadLogo()

                    // Re-use the record when this invoice was already saved once.
                    let id: String
                    if previousId.isEmpty {
                        id = try repository.save(invoice).id
                    } else {
                        id = previousId
                    }
                    let pdfURL = repository.pdfURL(id: id)
                    try generator.generate(invoice: invoice, profile: profile, logo: logo, invoiceId: id, to: pdfURL)
                    if previousId.isEmpty {
                        try repository.updatePdfPath(id: id, pdfPath: pdfURL.path)
                    } else {
                        try repository.update(id: id, invoice: invoice, pdfPath: pdfURL.path)
                    }
                    return (id, pdfURL)
                }.value
                self.savedId = result.0
                self.pdfURL = result.1
                self.state = .saved
                AppLog.invoiceViewModel.info("Saved invoice and PDF id=\(result.0, privacy: .public)")
            } catch {
                AppLog.invoiceViewModel.error("PDF generation failed: \(error.localizedDescription, privacy: .public)")
                self.fail("Failed to generate PDF: \(error.localizedDescription)")
            }
        }
    }

    func reset() {
        extractionTask?.cancel()
        extractionTask = nil
        state = .idle
        invoice = nil
        error = ""
        pdfURL = nil
        savedId = ""
    }
}
