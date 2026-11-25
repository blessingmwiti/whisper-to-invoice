import Foundation
import Testing

@testable import WhisperToInvoice

struct InvoiceParserTests {
    private let today = "2026-11-25"

    @Test func parsesPlainJSON() {
        let raw = """
            {"client_name":"John","date":"2026-11-20","items":[{"description":"Tomatoes","qty":3,"unit_price":100,"total":300}],
            "subtotal":300,"tax":48,"total":348,"currency":"KES","notes":"Thanks"}
            """
        let invoice = InvoiceParser.parse(raw: raw, today: today)
        #expect(invoice.clientName == "John")
        #expect(invoice.date == "2026-11-20")
        #expect(invoice.items.count == 1)
        #expect(invoice.items[0].description == "Tomatoes")
        #expect(invoice.items[0].total == 300)
        #expect(invoice.subtotal == 300)
        #expect(invoice.tax == 48)
        #expect(abs(invoice.taxPercent - 16) < 0.0001)
        #expect(invoice.total == 348)
        #expect(invoice.notes == "Thanks")
    }

    @Test func parsesJSONInsideCodeFences() {
        let raw = "```json\n{\"client_name\":null,\"items\":[],\"subtotal\":0,\"tax\":0,\"total\":0}\n```"
        let invoice = InvoiceParser.parse(raw: raw, today: today)
        #expect(invoice.clientName.isEmpty)
        #expect(invoice.date == today)
        #expect(invoice.currency == "KES")
    }

    @Test func parsesNumbersGivenAsStrings() {
        let raw = #"{"items":[{"description":"Onions","qty":"2","unit_price":"250,5"}],"subtotal":"501","total":"501"}"#
        let invoice = InvoiceParser.parse(raw: raw, today: today)
        #expect(invoice.items.first?.qty == 2)
        #expect(invoice.items.first?.unitPrice == 250.5)
        #expect(invoice.items.first?.total == 501)
        #expect(invoice.total == 501)
    }

    @Test func invalidOutputGivesEmptyInvoice() {
        let invoice = InvoiceParser.parse(raw: "Sorry, I could not understand the audio.", today: today)
        #expect(invoice.items.isEmpty)
        #expect(invoice.date == today)
        #expect(invoice.total == 0)
    }

    @Test func promptContainsTodayAndRules() {
        let prompt = InvoiceParser.buildPrompt(today: today)
        #expect(prompt.contains("use today: \(today)"))
        #expect(prompt.contains("Return ONLY the JSON, nothing else"))
    }
}

struct InvoiceTotalsTests {
    @Test func recalculateTotalsUsesTaxPercent() {
        var invoice = InvoiceData.empty()
        invoice.items = [
            InvoiceLineItem(description: "A", qty: 2, unitPrice: 100, total: 200),
            InvoiceLineItem(description: "B", qty: 1, unitPrice: 50, total: 50),
        ]
        invoice.taxPercent = 10
        invoice.recalculateTotals()
        #expect(invoice.subtotal == 250)
        #expect(invoice.tax == 25)
        #expect(invoice.total == 275)
    }
}

struct PcmWavTests {
    @Test func wrapsPcmWithA44ByteHeader() {
        let pcm = Data([0x01, 0x00, 0x02, 0x00, 0x03, 0x00])
        let wav = PcmWav.wrap(pcm: pcm)
        #expect(wav.count == 44 + pcm.count)
        #expect(String(decoding: wav[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: wav[36..<40], as: UTF8.self) == "data")
        #expect(Data(wav.suffix(pcm.count)) == pcm)
        // Chunk size = total - 8, little endian.
        let chunkSize = wav[4..<8].enumerated().reduce(0) { $0 | (Int($1.element) << (8 * $1.offset)) }
        #expect(chunkSize == wav.count - 8)
    }
}
