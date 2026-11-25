import Foundation
import os

/// Central loggers. Messages never contain audio, client names or other invoice content unless
/// explicitly marked `.private` (redacted in release builds and unattached logs).
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.whispertoinvoice.app"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let theme = Logger(subsystem: subsystem, category: "Theme")
    static let diagnostics = Logger(subsystem: subsystem, category: "InvoiceDiag")
    static let invoiceViewModel = Logger(subsystem: subsystem, category: "InvoiceExtractionVM")
    static let invoiceScreen = Logger(subsystem: subsystem, category: "InvoiceExtractionScreen")
    static let invoiceTask = Logger(subsystem: subsystem, category: "InvoiceExtractionTask")
    static let llm = Logger(subsystem: subsystem, category: "LlmChatModelHelper")
    static let recorder = Logger(subsystem: subsystem, category: "AudioRecorder")
    static let download = Logger(subsystem: subsystem, category: "ModelDownload")
    static let modelManager = Logger(subsystem: subsystem, category: "ModelManager")
    static let repository = Logger(subsystem: subsystem, category: "InvoiceRepository")
    static let profile = Logger(subsystem: subsystem, category: "BusinessProfile")
    static let pdf = Logger(subsystem: subsystem, category: "InvoicePdf")
}
