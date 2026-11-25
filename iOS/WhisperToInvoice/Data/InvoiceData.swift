import Foundation

/// One line on an invoice. Port of Android `InvoiceLineItem`.
struct InvoiceLineItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// Stable identity for SwiftUI lists. Not persisted.
    var id = UUID()
    var description: String
    var qty: Double
    var unitPrice: Double
    var total: Double

    enum CodingKeys: String, CodingKey {
        case description, qty, unitPrice, total
    }
}

/// An invoice. Port of Android `InvoiceData`.
struct InvoiceData: Codable, Equatable, Sendable {
    var clientName: String
    var date: String
    var items: [InvoiceLineItem]
    var subtotal: Double
    /// Tax rate as a percentage, e.g. 16.0 = 16%.
    var taxPercent: Double = 0.0
    /// Computed tax amount = subtotal * taxPercent / 100. Stored for PDF/serialisation.
    var tax: Double = 0.0
    var total: Double
    var currency: String = "KES"
    var notes: String = ""

    /// Today's date as `yyyy-MM-dd` (Android: `SimpleDateFormat("yyyy-MM-dd")`).
    static func today(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    static func empty() -> InvoiceData {
        InvoiceData(
            clientName: "",
            date: today(),
            items: [],
            subtotal: 0.0,
            taxPercent: 0.0,
            tax: 0.0,
            total: 0.0)
    }

    /// Recomputes `subtotal`, `tax` and `total` from the line items and `taxPercent`.
    mutating func recalculateTotals() {
        subtotal = items.reduce(0.0) { $0 + $1.total }
        tax = subtotal * taxPercent / 100.0
        total = subtotal + tax
    }
}

extension InvoiceData {
    /// Tolerant decoding: fields missing from older/foreign records fall back to the defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName) ?? ""
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? InvoiceData.today()
        items = try c.decodeIfPresent([InvoiceLineItem].self, forKey: .items) ?? []
        subtotal = try c.decodeIfPresent(Double.self, forKey: .subtotal) ?? 0.0
        taxPercent = try c.decodeIfPresent(Double.self, forKey: .taxPercent) ?? 0.0
        tax = try c.decodeIfPresent(Double.self, forKey: .tax) ?? 0.0
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0.0
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "KES"
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}
