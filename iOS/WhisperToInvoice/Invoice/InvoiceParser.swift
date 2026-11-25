import Foundation

/// Builds the extraction prompt and parses the model's JSON reply
/// (Android: `buildPrompt` / `parseInvoice` in `InvoiceExtractionViewModel`).
enum InvoiceParser {

    /// The instruction sent to Gemma together with the audio clip. Identical to Android's prompt.
    static func buildPrompt(today: String) -> String {
        """
        Listen carefully to the audio recording. The speaker is describing a sale in their own language.

        Extract the invoice details and return ONLY a valid JSON object — no explanation, no markdown, no code fences. Just the raw JSON.

        JSON structure:
        {
          "client_name": "string or null if not mentioned",
          "date": "\(today)",
          "items": [
            { "description": "item name", "qty": 1.0, "unit_price": 0.0, "total": 0.0 }
          ],
          "subtotal": 0.0,
          "tax": 0.0,
          "total": 0.0,
          "currency": "KES",
          "notes": ""
        }

        Rules:
        - Calculate total = qty × unit_price for each item if not stated
        - Calculate subtotal = sum of all item totals
        - Calculate final total = subtotal + tax
        - If currency not stated, default to KES
        - If date not stated, use today: \(today)
        - Swahili number words: moja=1, mbili=2, tatu=3, nne=4, tano=5, sita=6, saba=7, nane=8, tisa=9, kumi=10
        - Return ONLY the JSON, nothing else
        """
    }

    /// Parses the raw model output. Returns an empty invoice when the output is not valid JSON
    /// (same as Android), so the user can still fill it in by hand.
    static func parse(raw: String, today: String) -> InvoiceData {
        guard let json = extractJSONObject(from: raw),
            let data = json.data(using: .utf8),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            AppLog.invoiceViewModel.warning("Failed to parse invoice JSON (responseChars=\(raw.count, privacy: .public))")
            var empty = InvoiceData.empty()
            empty.date = today
            return empty
        }

        let subtotal = number(object["subtotal"]) ?? 0.0
        let taxAmount = number(object["tax"]) ?? 0.0
        // Gemma returns a flat tax amount; convert it to a percentage so the UI shows a rate.
        let taxPercent = subtotal > 0.0 ? (taxAmount / subtotal * 100.0) : 0.0

        var items: [InvoiceLineItem] = []
        if let rawItems = object["items"] as? [Any] {
            for rawItem in rawItems {
                guard let dict = rawItem as? [String: Any] else { continue }
                let qty = number(dict["qty"]) ?? 1.0
                let unitPrice = number(dict["unit_price"]) ?? 0.0
                items.append(
                    InvoiceLineItem(
                        description: string(dict["description"]) ?? "",
                        qty: qty,
                        unitPrice: unitPrice,
                        total: number(dict["total"]) ?? (qty * unitPrice)))
            }
        }

        return InvoiceData(
            clientName: string(object["client_name"]) ?? "",
            date: string(object["date"]) ?? today,
            items: items,
            subtotal: subtotal,
            taxPercent: taxPercent,
            tax: taxAmount,
            total: number(object["total"]) ?? (subtotal + taxAmount),
            currency: string(object["currency"]) ?? "KES",
            notes: string(object["notes"]) ?? "")
    }

    /// Removes markdown code fences and keeps the text from the first `{` to the last `}`.
    static func extractJSONObject(from raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```json") {
            text.removeFirst("```json".count)
        } else if text.hasPrefix("```") {
            text.removeFirst(3)
        }
        if text.hasSuffix("```") { text.removeLast(3) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return nil
        }
        return String(text[start...end])
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            // JSON booleans bridge to NSNumber too; they are not valid numbers here.
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let result = number.doubleValue
            return result.isFinite ? result : nil
        case let text as String:
            return Fmt.parseDecimal(text)
        default:
            return nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String: return text
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): return number.stringValue
        default: return nil
        }
    }
}
