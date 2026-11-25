import Foundation

/// A saved invoice record. The JSON layout matches the Android `SavedInvoice` (`createdAt` is
/// epoch milliseconds).
struct SavedInvoice: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var invoice: InvoiceData
    let createdAt: Int64
    var pdfPath: String = ""

    var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0) }
}

extension SavedInvoice {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        invoice = try c.decode(InvoiceData.self, forKey: .invoice)
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        pdfPath = try c.decodeIfPresent(String.self, forKey: .pdfPath) ?? ""
    }
}

/// File-based invoice storage (Android: `filesDir/invoices/invoice_<id>.json` + `.pdf`).
final class InvoiceRepository: @unchecked Sendable {
    private let directory: URL
    private let fileManager = FileManager.default

    init(baseDirectory: URL? = nil) {
        let base = baseDirectory ?? AppDirectories.applicationSupport
        self.directory = base.appendingPathComponent("invoices", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    /// Only canonical UUID strings are accepted as ids so an id can never escape `directory`.
    private func isValid(id: String) -> Bool {
        UUID(uuidString: id) != nil
    }

    private func jsonURL(id: String) -> URL { directory.appendingPathComponent("invoice_\(id).json") }

    func pdfURL(id: String) -> URL { directory.appendingPathComponent("invoice_\(id).pdf") }

    func hasPdf(id: String) -> Bool {
        isValid(id: id) && fileManager.fileExists(atPath: pdfURL(id: id).path)
    }

    @discardableResult
    func save(_ invoice: InvoiceData, pdfPath: String = "") throws -> SavedInvoice {
        let saved = SavedInvoice(
            id: UUID().uuidString.lowercased(),
            invoice: invoice,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000.0),
            pdfPath: pdfPath)
        let data = try JSONEncoder().encode(saved)
        try data.write(to: jsonURL(id: saved.id), options: writeOptions)
        AppLog.repository.info("Saved invoice record id=\(saved.id, privacy: .public) items=\(invoice.items.count)")
        return saved
    }

    /// Replaces the stored invoice content of an existing record (used when a saved invoice is
    /// edited and its PDF regenerated, so no duplicate record is created).
    func update(id: String, invoice: InvoiceData, pdfPath: String) throws {
        guard isValid(id: id) else {
            AppLog.repository.error("update rejected invalid id")
            return
        }
        let url = jsonURL(id: id)
        guard fileManager.fileExists(atPath: url.path) else {
            AppLog.repository.warning("update: record \(id, privacy: .public) not found")
            return
        }
        var saved = try JSONDecoder().decode(SavedInvoice.self, from: Data(contentsOf: url))
        saved.invoice = invoice
        saved.pdfPath = pdfPath
        try JSONEncoder().encode(saved).write(to: url, options: writeOptions)
        AppLog.repository.info("Updated invoice record id=\(id, privacy: .public) items=\(invoice.items.count)")
    }

    func updatePdfPath(id: String, pdfPath: String) throws {
        guard isValid(id: id) else {
            AppLog.repository.error("updatePdfPath rejected invalid id")
            return
        }
        let url = jsonURL(id: id)
        guard fileManager.fileExists(atPath: url.path) else {
            AppLog.repository.warning("updatePdfPath: record \(id, privacy: .public) not found")
            return
        }
        var saved = try JSONDecoder().decode(SavedInvoice.self, from: Data(contentsOf: url))
        saved.pdfPath = pdfPath
        try JSONEncoder().encode(saved).write(to: url, options: writeOptions)
    }

    func listAll() -> [SavedInvoice] {
        let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        var result: [SavedInvoice] = []
        for url in urls where url.lastPathComponent.hasPrefix("invoice_") && url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let saved = try decoder.decode(SavedInvoice.self, from: data)
                guard isValid(id: saved.id) else { continue }
                result.append(saved)
            } catch {
                AppLog.repository.warning("Skipping unreadable invoice record: \(error.localizedDescription, privacy: .public)")
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    func delete(id: String) {
        guard isValid(id: id) else {
            AppLog.repository.error("delete rejected invalid id")
            return
        }
        try? fileManager.removeItem(at: jsonURL(id: id))
        try? fileManager.removeItem(at: pdfURL(id: id))
        AppLog.repository.info("Deleted invoice id=\(id, privacy: .public)")
    }
}
