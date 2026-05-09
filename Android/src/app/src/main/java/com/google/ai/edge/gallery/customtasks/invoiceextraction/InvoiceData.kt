package com.google.ai.edge.gallery.customtasks.invoiceextraction

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class InvoiceLineItem(
  val description: String,
  val qty: Double,
  val unitPrice: Double,
  val total: Double,
)

data class InvoiceData(
  val clientName: String,
  val date: String,
  val items: List<InvoiceLineItem>,
  val subtotal: Double,
  val tax: Double,
  val total: Double,
  val currency: String = "KES",
  val notes: String = "",
) {
  companion object {
    fun today(): String =
      SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

    /** Fallback invoice used when Gemma returns unstructured text. */
    fun empty() = InvoiceData(
      clientName = "",
      date = today(),
      items = emptyList(),
      subtotal = 0.0,
      tax = 0.0,
      total = 0.0,
    )
  }
}
