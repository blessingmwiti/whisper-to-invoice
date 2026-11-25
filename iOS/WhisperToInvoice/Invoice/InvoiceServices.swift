import Observation

/// Shared storage objects for the invoice flow and its screens.
@MainActor
@Observable
final class InvoiceServices {
    @ObservationIgnored let invoices: InvoiceRepository
    @ObservationIgnored let profile: BusinessProfileRepository

    init(
        invoices: InvoiceRepository = InvoiceRepository(),
        profile: BusinessProfileRepository = BusinessProfileRepository()
    ) {
        self.invoices = invoices
        self.profile = profile
    }
}
