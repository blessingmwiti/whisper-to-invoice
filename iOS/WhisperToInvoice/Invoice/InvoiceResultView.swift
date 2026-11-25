import SwiftUI

/// The editable invoice preview (Android: `InvoiceResultContent`).
struct InvoiceResultView: View {
    let viewModel: InvoiceExtractionViewModel

    private var invoice: InvoiceData { viewModel.invoice ?? .empty() }
    private var pdfReady: Bool { viewModel.state == .saved && viewModel.pdfURL != nil }

    private static let actionsID = "invoice-actions"

    var body: some View {
        ScrollViewReader { proxy in
            scrollContent
                .onAppear {
                    // After saving, the PDF actions are what the user needs next.
                    if pdfReady { proxy.scrollTo(Self.actionsID, anchor: .bottom) }
                }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text("Tap any field to edit before saving")
                    .appText(.bodySmall)
                    .foregroundStyle(AppPalette.onSurfaceVariant)
                    .padding(.bottom, 16)

                clientCard
                itemsCard.padding(.top, 12)
                totalsCard.padding(.top, 12)

                LabeledTextField(
                    title: "Notes (optional)",
                    text: Binding(get: { invoice.notes }, set: { viewModel.updateNotes($0) }),
                    axis: .vertical,
                    lineLimit: 2...4
                )
                .padding(.top, 12)

                actions.padding(.top, 24).id(Self.actionsID)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        HStack {
            Text("Invoice Preview")
                .appText(.titleLarge, weight: .bold)
                .foregroundStyle(AppPalette.onSurface)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                viewModel.reset()
            } label: {
                Label("New", systemImage: "arrow.clockwise")
                    .appText(.labelLarge)
            }
            .buttonStyle(.glass)
            .tint(AppPalette.primary)
        }
    }

    // MARK: Client / date / currency

    private var clientCard: some View {
        VStack(spacing: 8) {
            LabeledTextField(
                title: "Client name",
                text: Binding(get: { invoice.clientName }, set: { viewModel.updateClient($0) }),
                capitalization: .words)
            HStack(alignment: .top, spacing: 8) {
                LabeledTextField(
                    title: "Date",
                    text: Binding(get: { invoice.date }, set: { viewModel.updateDate($0) }),
                    capitalization: .never)
                LabeledTextField(
                    title: "Currency",
                    text: Binding(get: { invoice.currency }, set: { viewModel.updateCurrency($0) }),
                    capitalization: .characters)
                    .frame(width: 100)
            }
        }
        .padding(16)
        .surfaceCard()
    }

    // MARK: Items

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Items")
                    .appText(.labelLarge, weight: .bold)
                    .foregroundStyle(AppPalette.onSurface)
                Spacer()
                Button {
                    viewModel.addItem()
                } label: {
                    Label("Add item", systemImage: "plus")
                        .appText(.labelLarge)
                }
                .buttonStyle(.glass)
                .tint(AppPalette.primary)
            }

            if invoice.items.isEmpty {
                Text("No items — tap \"Add item\" or record again")
                    .appText(.bodySmall)
                    .foregroundStyle(AppPalette.error)
            } else {
                ForEach(Array(invoice.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().padding(.vertical, 8)
                    }
                    LineItemEditor(
                        item: item,
                        currency: invoice.currency,
                        onChange: { viewModel.updateItem(at: index, $0) },
                        onRemove: { viewModel.removeItem(at: index) })
                }
            }
        }
        .padding(16)
        .surfaceCard()
    }

    // MARK: Totals

    private var totalsCard: some View {
        VStack(spacing: 4) {
            totalRow("Subtotal", amount: invoice.subtotal)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tax").appText(.bodyMedium).foregroundStyle(AppPalette.onSurface)
                    if invoice.tax > 0 {
                        Text("\(invoice.currency) \(Fmt.amount(invoice.tax))")
                            .appText(.bodySmall)
                            .foregroundStyle(AppPalette.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NumberField(
                    title: "%",
                    value: invoice.taxPercent,
                    blankWhenZero: true,
                    placeholder: "0",
                    suffix: "%",
                    onCommit: { viewModel.updateTaxPercent($0) }
                )
                .frame(width: 110)
            }

            Divider().padding(.vertical, 4)

            HStack {
                Text("TOTAL").appText(.titleSmall, weight: .bold)
                Spacer()
                Text("\(invoice.currency) \(Fmt.amount(invoice.total))").appText(.titleSmall, weight: .bold)
            }
            .foregroundStyle(AppPalette.onSurface)
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .surfaceCard()
    }

    private func totalRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label).appText(.bodyMedium)
            Spacer()
            Text("\(invoice.currency) \(Fmt.amount(amount))").appText(.bodyMedium)
        }
        .foregroundStyle(AppPalette.onSurface)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if pdfReady, let url = viewModel.pdfURL {
                ShareLink(
                    item: url,
                    subject: Text("Invoice – \(shareName)"),
                    message: Text("Please find your invoice attached.")
                ) {
                    PrimaryActionLabel(title: "Share via WhatsApp", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glassProminent)
                .tint(AppPalette.primary)

                Button {
                    viewModel.saveAndGeneratePdf()
                } label: {
                    PrimaryActionLabel(title: "Regenerate PDF", systemImage: "doc.richtext")
                }
                .buttonStyle(.glass)
                .tint(AppPalette.primary)
            } else {
                Button {
                    viewModel.saveAndGeneratePdf()
                } label: {
                    PrimaryActionLabel(title: "Generate PDF & Save", systemImage: "doc.richtext")
                }
                .buttonStyle(.glassProminent)
                .tint(AppPalette.primary)
            }
        }
    }

    private var shareName: String {
        invoice.clientName.isEmpty ? "invoice" : invoice.clientName
    }
}

/// One editable line item (Android: `LineItemEditor`).
private struct LineItemEditor: View {
    let item: InvoiceLineItem
    let currency: String
    let onChange: (InvoiceLineItem) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                LabeledTextField(
                    title: "Description",
                    text: Binding(
                        get: { item.description },
                        set: { newValue in
                            var updated = item
                            updated.description = newValue
                            onChange(updated)
                        }))
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(AppPalette.error.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove item")
            }
            HStack(alignment: .top, spacing: 8) {
                NumberField(
                    title: "Qty",
                    value: item.qty,
                    onCommit: { qty in
                        var updated = item
                        updated.qty = qty
                        updated.total = qty * item.unitPrice
                        onChange(updated)
                    })
                    .frame(width: 110)
                NumberField(
                    title: "Unit price (\(currency))",
                    value: item.unitPrice,
                    blankWhenZero: true,
                    onCommit: { price in
                        var updated = item
                        updated.unitPrice = price
                        updated.total = item.qty * price
                        onChange(updated)
                    })
                    .frame(maxWidth: .infinity)
            }
            Text("Line total: \(currency) \(Fmt.amount(item.total))")
                .appText(.bodySmall)
                .foregroundStyle(AppPalette.onSurfaceVariant)
                .padding(.top, 2)
        }
    }
}
