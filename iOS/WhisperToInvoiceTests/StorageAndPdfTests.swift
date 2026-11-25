import Foundation
import Testing

@testable import WhisperToInvoice

struct StorageAndPdfTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleInvoice() -> InvoiceData {
        var invoice = InvoiceData.empty()
        invoice.clientName = "Jane"
        invoice.items = [InvoiceLineItem(description: "Rice", qty: 2, unitPrice: 150, total: 300)]
        invoice.taxPercent = 16
        invoice.recalculateTotals()
        return invoice
    }

    @Test func repositorySavesListsUpdatesAndDeletes() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = InvoiceRepository(baseDirectory: directory)

        let saved = try repository.save(sampleInvoice())
        #expect(repository.listAll().count == 1)
        #expect(repository.listAll().first?.invoice.clientName == "Jane")

        var changed = sampleInvoice()
        changed.clientName = "Joe"
        try repository.update(id: saved.id, invoice: changed, pdfPath: "")
        #expect(repository.listAll().count == 1)
        #expect(repository.listAll().first?.invoice.clientName == "Joe")

        repository.delete(id: saved.id)
        #expect(repository.listAll().isEmpty)
    }

    @Test func repositoryRejectsIdsThatAreNotUUIDs() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = InvoiceRepository(baseDirectory: directory)
        let outside = directory.appendingPathComponent("keep.txt")
        try Data("x".utf8).write(to: outside)

        repository.delete(id: "../keep")
        #expect(FileManager.default.fileExists(atPath: outside.path))
        #expect(!repository.hasPdf(id: "../keep"))
    }

    @Test func pdfIsGenerated() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("invoice.pdf")
        var profile = BusinessProfile()
        profile.businessName = "Acme General Store"
        profile.paymentInstructions = "M-Pesa: 0700 000 000"

        try InvoicePdfGenerator().generate(
            invoice: sampleInvoice(), profile: profile, logo: nil, invoiceId: UUID().uuidString, to: url)

        let data = try Data(contentsOf: url)
        #expect(data.count > 500)
        #expect(String(decoding: data.prefix(5), as: UTF8.self) == "%PDF-")
    }

    @Test func businessProfileRoundTrips() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = BusinessProfileRepository(defaults: defaults, baseDirectory: directory)

        var profile = BusinessProfile()
        profile.businessName = "Acme"
        profile.phone = "+254 712 345 678"
        repository.save(profile)

        #expect(repository.get() == profile)
    }
}
