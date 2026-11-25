import Foundation

/// Number / size formatting shared by the UI and the PDF generator.
enum Fmt {
    /// `"%,.2f"` — grouped, two decimals, current locale (Android: `"%,.2f".format(x)`).
    static func amount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// Whole numbers without decimals, otherwise two decimals (Android quantity/percent display).
    static func quantity(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(format: "%.2f", value)
    }

    /// Plain text for editing a number: whole numbers without decimals, otherwise the shortest
    /// round-trippable representation.
    static func editableNumber(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    /// SI units (1000-based), like Android `Long.humanReadableSize`.
    static func humanReadableSize(_ bytes: Int64, extraDecimalForGbAndAbove: Bool = false) -> String {
        let unit = 1000.0
        let value = Double(bytes)
        if value < unit { return "\(bytes) B" }
        let exp = Int(log(value) / log(unit))
        let prefixes = Array("kMGTPE")
        let prefix = prefixes[min(exp - 1, prefixes.count - 1)]
        let scaled = value / pow(unit, Double(exp))
        let useTwoDecimals = extraDecimalForGbAndAbove && prefix != "k" && prefix != "M"
        let format = useTwoDecimals ? "%.2f %@B" : "%.1f %@B"
        return String(format: format, scaled, String(prefix))
    }

    /// Parses a user-typed decimal that may use a comma as the decimal separator.
    static func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let value = Double(trimmed) { return value.isFinite ? value : nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) { return value.isFinite ? value : nil }
        return nil
    }
}
