import UIKit

/// Generates the A4 invoice PDF with the same layout as Android's `InvoicePdfGenerator`
/// (A4 at 72 DPI: 595 × 842 points, single page). 100% offline, no third-party code.
struct InvoicePdfGenerator {
    private let pageWidth: CGFloat = 595
    private let pageHeight: CGFloat = 842
    private let margin: CGFloat = 48
    private let colQtyW: CGFloat = 40
    private let colPriceW: CGFloat = 80
    private let colTotalW: CGFloat = 80

    // Android Color.* constants.
    private let gray = UIColor(red: 0x88 / 255, green: 0x88 / 255, blue: 0x88 / 255, alpha: 1)
    private let darkGray = UIColor(red: 0x44 / 255, green: 0x44 / 255, blue: 0x44 / 255, alpha: 1)
    private let lightGray = UIColor(red: 0xCC / 255, green: 0xCC / 255, blue: 0xCC / 255, alpha: 1)
    private let ink = UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x2E / 255, alpha: 1)
    private let body = UIColor(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255, alpha: 1)

    private enum Align { case left, right, center }

    /// Writes the PDF to `url`. `logo` is the already-loaded business logo, if any.
    func generate(
        invoice: InvoiceData,
        profile: BusinessProfile,
        logo: UIImage?,
        invoiceId: String,
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Invoice",
            kCGPDFContextCreator as String: "Whisper to Invoice",
        ]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            draw(invoice: invoice, profile: profile, logo: logo, invoiceId: invoiceId)
        }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path)
        AppLog.pdf.info("PDF written (items=\(invoice.items.count, privacy: .public))")
    }

    // MARK: - Drawing

    private func draw(invoice: InvoiceData, profile: BusinessProfile, logo: UIImage?, invoiceId: String) {
        var y = margin

        // Logo.
        if let logo, logo.size.height > 0 {
            let logoH: CGFloat = 60
            let logoW = logoH * logo.size.width / logo.size.height
            logo.draw(in: CGRect(x: margin, y: y, width: logoW, height: logoH))
        }

        // Business header (right-aligned).
        let rightX = pageWidth - margin
        if !profile.businessName.isEmpty {
            text(profile.businessName, x: rightX, baseline: y + 14, size: 18, bold: true, color: ink, align: .right)
            y += 18

            if !profile.tagline.isEmpty {
                text(profile.tagline, x: rightX, baseline: y + 10, size: 9, color: gray, align: .right)
                y += 12
            }
            if !profile.address.isEmpty {
                for line in profile.address.components(separatedBy: .newlines) {
                    text(line.trimmingCharacters(in: .whitespaces), x: rightX, baseline: y + 10, size: 9, color: darkGray, align: .right)
                    y += 11
                }
            }
            if !profile.phone.isEmpty {
                text(profile.phone, x: rightX, baseline: y + 10, size: 9, color: darkGray, align: .right)
                y += 11
            }
            if !profile.email.isEmpty {
                text(profile.email, x: rightX, baseline: y + 10, size: 9, color: darkGray, align: .right)
                y += 11
            }
        }

        y = max(y, margin + 70)

        // Divider.
        y += 12
        hLine(y: y)
        y += 10

        // "INVOICE" title + meta.
        text("INVOICE", x: margin, baseline: y + 24, size: 26, bold: true, color: ink, align: .left)
        let shortId = String(invoiceId.suffix(8)).uppercased()
        text("Invoice #: \(shortId)", x: rightX, baseline: y + 10, size: 9, color: darkGray, align: .right)
        text("Date: \(invoice.date)", x: rightX, baseline: y + 22, size: 9, color: darkGray, align: .right)
        y += 36

        // Bill to.
        if !invoice.clientName.isEmpty {
            text("BILL TO", x: margin, baseline: y + 10, size: 8, bold: true, color: gray, align: .left)
            y += 12
            text(invoice.clientName, x: margin, baseline: y + 12, size: 11, color: ink, align: .left)
            y += 16
        }

        y += 12

        // Items table header.
        let contentWidth = pageWidth - 2 * margin
        let colDescW = contentWidth - colQtyW - colPriceW - colTotalW
        let qtyX = margin + colDescW + colQtyW
        let priceX = qtyX + colPriceW
        let totalX = priceX + colTotalW

        let headerColor = UIColor(red: 0x66 / 255, green: 0x66 / 255, blue: 0x66 / 255, alpha: 1)
        text("DESCRIPTION", x: margin + 4, baseline: y + 10, size: 8, bold: true, color: headerColor, align: .left)
        text("QTY", x: qtyX, baseline: y + 10, size: 8, bold: true, color: headerColor, align: .right)
        text("UNIT PRICE", x: priceX, baseline: y + 10, size: 8, bold: true, color: headerColor, align: .right)
        text("TOTAL", x: totalX, baseline: y + 10, size: 8, bold: true, color: headerColor, align: .right)
        y += 20
        hLine(y: y, width: 1, color: lightGray)
        y += 6

        // Item rows.
        let stripe = UIColor(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF7 / 255, alpha: 1)
        for (index, item) in invoice.items.enumerated() {
            if index % 2 == 0 {
                stripe.setFill()
                UIRectFill(CGRect(x: margin, y: y - 2, width: pageWidth - 2 * margin, height: 16))
            }
            text(String(item.description.prefix(45)), x: margin + 4, baseline: y + 10, size: 9, color: body, align: .left)
            text(Fmt.quantity(item.qty), x: qtyX, baseline: y + 10, size: 9, color: body, align: .right)
            text(Fmt.amount(item.unitPrice), x: priceX, baseline: y + 10, size: 9, color: body, align: .right)
            text(Fmt.amount(item.total), x: totalX, baseline: y + 10, size: 9, color: body, align: .right)
            y += 16
        }

        y += 8
        hLine(y: y, width: 1, color: lightGray)
        y += 10

        // Totals.
        totalRow(y: y, label: "Subtotal", currency: invoice.currency, amount: invoice.subtotal)
        y += 16
        if invoice.tax > 0 {
            let label = invoice.taxPercent > 0 ? "Tax (\(Fmt.quantity(invoice.taxPercent))%)" : "Tax"
            totalRow(y: y, label: label, currency: invoice.currency, amount: invoice.tax)
            y += 16
            hLine(y: y, width: 0.5, color: UIColor(red: 0xDD / 255, green: 0xDD / 255, blue: 0xDD / 255, alpha: 1))
            y += 8
        }
        text("TOTAL", x: margin, baseline: y + 12, size: 11, bold: true, color: ink, align: .left)
        text("\(invoice.currency) \(Fmt.amount(invoice.total))", x: rightX, baseline: y + 12, size: 11, bold: true, color: ink, align: .right)
        y += 24

        // Notes.
        if !invoice.notes.isEmpty {
            text("Notes: \(invoice.notes)", x: margin, baseline: y + 10, size: 8, color: gray, align: .left)
            y += 16
        }

        // Payment instructions footer.
        if !profile.paymentInstructions.isEmpty {
            let lines = profile.paymentInstructions.components(separatedBy: .newlines)
            y = pageHeight - margin - CGFloat(lines.count) * 11 - 24
            hLine(y: y, width: 0.5, color: lightGray)
            y += 10
            text("PAYMENT DETAILS", x: margin, baseline: y + 10, size: 8, bold: true, color: darkGray, align: .left)
            y += 12
            for line in lines {
                text(line.trimmingCharacters(in: .whitespaces), x: margin, baseline: y + 10, size: 8, color: gray, align: .left)
                y += 11
            }
        }

        // App watermark.
        text(
            "Generated by Whisper to Invoice · Powered by Gemma 4 · 100% offline",
            x: pageWidth / 2, baseline: pageHeight - 10, size: 7, color: lightGray, align: .center)
    }

    private func totalRow(y: CGFloat, label: String, currency: String, amount: Double) {
        text(label, x: margin, baseline: y + 10, size: 9, color: darkGray, align: .left)
        text("\(currency) \(Fmt.amount(amount))", x: pageWidth - margin, baseline: y + 10, size: 9, color: body, align: .right)
    }

    private func hLine(y: CGFloat, width: CGFloat = 1, color: UIColor = UIColor(red: 0xDD / 255, green: 0xDD / 255, blue: 0xDD / 255, alpha: 1)) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    /// Draws a single line of text so that its baseline sits at `baseline` (Android `drawText`
    /// semantics). `x` is the left edge, right edge or centre depending on `align`.
    private func text(
        _ string: String,
        x: CGFloat,
        baseline: CGFloat,
        size: CGFloat,
        bold: Bool = false,
        color: UIColor,
        align: Align
    ) {
        let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let width = attributed.size().width
        let originX: CGFloat
        switch align {
        case .left: originX = x
        case .right: originX = x - width
        case .center: originX = x - width / 2
        }
        attributed.draw(at: CGPoint(x: originX, y: baseline - font.ascender))
    }
}
