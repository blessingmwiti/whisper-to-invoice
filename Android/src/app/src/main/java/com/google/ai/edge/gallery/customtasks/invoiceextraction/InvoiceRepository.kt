package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.content.Context
import com.google.gson.Gson
import java.io.File
import java.util.UUID

data class SavedInvoice(
  val id: String,
  val invoice: InvoiceData,
  val createdAt: Long,
  val pdfPath: String = "",
)

class InvoiceRepository(context: Context) {
  private val invoicesDir = File(context.filesDir, "invoices").also { it.mkdirs() }
  private val gson = Gson()

  fun save(invoice: InvoiceData, pdfPath: String = ""): SavedInvoice {
    val saved = SavedInvoice(
      id = UUID.randomUUID().toString(),
      invoice = invoice,
      createdAt = System.currentTimeMillis(),
      pdfPath = pdfPath,
    )
    File(invoicesDir, "invoice_${saved.id}.json").writeText(gson.toJson(saved))
    return saved
  }

  fun updatePdfPath(id: String, pdfPath: String) {
    val file = File(invoicesDir, "invoice_$id.json")
    if (!file.exists()) return
    val saved = gson.fromJson(file.readText(), SavedInvoice::class.java) ?: return
    file.writeText(gson.toJson(saved.copy(pdfPath = pdfPath)))
  }

  fun listAll(): List<SavedInvoice> {
    return invoicesDir
      .listFiles { f -> f.name.startsWith("invoice_") && f.name.endsWith(".json") }
      ?.mapNotNull { f ->
        try { gson.fromJson(f.readText(), SavedInvoice::class.java) } catch (_: Exception) { null }
      }
      ?.sortedByDescending { it.createdAt }
      ?: emptyList()
  }

  fun delete(id: String) {
    File(invoicesDir, "invoice_$id.json").delete()
    File(invoicesDir, "invoice_$id.pdf").also { if (it.exists()) it.delete() }
  }

  fun pdfFile(id: String): File = File(invoicesDir, "invoice_$id.pdf")
}
