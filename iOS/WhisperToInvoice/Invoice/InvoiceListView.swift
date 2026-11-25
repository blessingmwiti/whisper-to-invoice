import SwiftUI

/// "My Invoices" (Android: `InvoiceListScreen`).
struct InvoiceListView: View {
    @Environment(InvoiceServices.self) private var services

    @State private var invoices: [SavedInvoice] = []
    @State private var deleteTarget: SavedInvoice?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "dd MMM yyyy · HH:mm"
        return formatter
    }()

    var body: some View {
        Group {
            if invoices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(invoices) { saved in
                            InvoiceCard(
                                saved: saved,
                                dateText: Self.dateFormatter.string(from: saved.createdDate),
                                pdfURL: services.invoices.hasPdf(id: saved.id)
                                    ? services.invoices.pdfURL(id: saved.id) : nil,
                                onDelete: { deleteTarget = saved })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background { AppBackground() }
        .appNavigationTitle("My Invoices")
        .task { await reload() }
        .alert("Delete invoice?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    Task { await delete(target) }
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget {
                let client = target.invoice.clientName.isEmpty ? "Unknown client" : target.invoice.clientName
                Text("Delete invoice for \"\(client)\" dated \(target.invoice.date)? This cannot be undone.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Image(systemName: "receipt")
                .font(.system(size: 56))
                .foregroundStyle(AppPalette.onSurfaceVariant.opacity(0.4))
                .accessibilityHidden(true)
            Text("No invoices yet")
                .appText(.titleMedium)
                .foregroundStyle(AppPalette.onSurfaceVariant)
                .padding(.top, 12)
            Text("Speak a sale to create your first invoice")
                .appText(.bodySmall)
                .foregroundStyle(AppPalette.onSurfaceVariant.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() async {
        let repository = services.invoices
        let list = await Task.detached(priority: .userInitiated) { repository.listAll() }.value
        invoices = list
    }

    private func delete(_ saved: SavedInvoice) async {
        let repository = services.invoices
        let id = saved.id
        await Task.detached(priority: .userInitiated) { repository.delete(id: id) }.value
        deleteTarget = nil
        await reload()
    }
}

private struct InvoiceCard: View {
    let saved: SavedInvoice
    let dateText: String
    let pdfURL: URL?
    let onDelete: () -> Void

    private var shareName: String {
        saved.invoice.clientName.isEmpty ? "invoice" : saved.invoice.clientName
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(saved.invoice.clientName.isEmpty ? "Unknown client" : saved.invoice.clientName)
                    .appText(.titleSmall, weight: .semiBold)
                    .foregroundStyle(AppPalette.onSurface)
                Text(dateText)
                    .appText(.bodySmall)
                    .foregroundStyle(AppPalette.onSurfaceVariant)
                Text("\(saved.invoice.currency) \(Fmt.amount(saved.invoice.total))")
                    .appText(.bodyMedium, weight: .medium)
                    .foregroundStyle(AppPalette.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if let pdfURL {
                ShareLink(
                    item: pdfURL,
                    subject: Text("Invoice – \(shareName)"),
                    message: Text("Please find your invoice attached.")
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share PDF")
            } else {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(AppPalette.onSurfaceVariant.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(AppPalette.error.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Delete")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 20)
    }
}
