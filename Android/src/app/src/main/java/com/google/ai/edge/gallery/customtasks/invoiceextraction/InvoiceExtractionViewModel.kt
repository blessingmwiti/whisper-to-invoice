package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.ai.edge.gallery.data.Model
import com.google.ai.edge.gallery.ui.llmchat.LlmChatModelHelper
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

private const val TAG = "InvoiceExtractionVM"

enum class ExtractionState {
  IDLE,       // waiting for user to record
  PROCESSING, // Gemma 4 is running
  DONE,       // invoice extracted, user can edit / save
  SAVING,     // generating PDF + saving
  SAVED,      // PDF ready — show share button
  ERROR,
}

data class InvoiceExtractionUiState(
  val state: ExtractionState = ExtractionState.IDLE,
  /** Editable copy shown on the result screen. Mutated by user edits. */
  val invoice: InvoiceData? = null,
  val rawResponse: String = "",
  val error: String = "",
  /** Absolute path of the generated PDF, set after SAVED. */
  val pdfPath: String = "",
  /** ID of the saved invoice record. */
  val savedId: String = "",
)

@HiltViewModel
class InvoiceExtractionViewModel @Inject constructor(
  @ApplicationContext private val appContext: Context,
) : ViewModel() {

  private val _uiState = MutableStateFlow(InvoiceExtractionUiState())
  val uiState = _uiState.asStateFlow()

  private val gson = Gson()
  private val repo by lazy { InvoiceRepository(appContext) }
  private val pdfGen by lazy { InvoicePdfGenerator(appContext) }
  private val profileRepo by lazy { BusinessProfileRepository(appContext) }

  // ---------------------------------------------------------------------------
  // Audio → Gemma 4 → invoice JSON
  // ---------------------------------------------------------------------------

  fun extractInvoice(model: Model, audioPcmBytes: ByteArray) {
    _uiState.update { it.copy(state = ExtractionState.PROCESSING, error = "", rawResponse = "") }

    viewModelScope.launch(Dispatchers.Default) {
      var waited = 0
      while (model.instance == null && waited < 30_000) {
        kotlinx.coroutines.delay(200)
        waited += 200
      }
      if (model.instance == null) {
        _uiState.update { it.copy(state = ExtractionState.ERROR, error = "Model not ready. Try again.") }
        return@launch
      }

      val today = InvoiceData.today()
      val prompt = buildPrompt(today)
      val wavBytes = pcmToWav(audioPcmBytes)
      val accumulated = StringBuilder()

      LlmChatModelHelper.runInference(
        model = model,
        input = prompt,
        audioClips = listOf(wavBytes),
        resultListener = { partial, done, _ ->
          accumulated.append(partial)
          if (done) {
            val raw = accumulated.toString().trim()
            Log.d(TAG, "Gemma raw: $raw")
            val invoice = parseInvoice(raw, today)
            _uiState.update {
              it.copy(state = ExtractionState.DONE, invoice = invoice, rawResponse = raw)
            }
          }
        },
        cleanUpListener = {},
        onError = { err ->
          Log.e(TAG, "Inference error: $err")
          _uiState.update { it.copy(state = ExtractionState.ERROR, error = err) }
        },
      )
    }
  }

  // ---------------------------------------------------------------------------
  // User edits — called from the result screen as the user types
  // ---------------------------------------------------------------------------

  fun updateClient(name: String) = mutateInvoice { it.copy(clientName = name) }
  fun updateDate(date: String) = mutateInvoice { it.copy(date = date) }
  fun updateNotes(notes: String) = mutateInvoice { it.copy(notes = notes) }
  fun updateCurrency(currency: String) = mutateInvoice { it.copy(currency = currency) }

  fun updateItem(index: Int, item: InvoiceLineItem) {
    mutateInvoice { inv ->
      val items = inv.items.toMutableList()
      if (index in items.indices) items[index] = item
      val subtotal = items.sumOf { it.total }
      inv.copy(items = items, subtotal = subtotal, total = subtotal + inv.tax)
    }
  }

  fun addItem() {
    mutateInvoice { inv ->
      val items = inv.items + InvoiceLineItem("", 1.0, 0.0, 0.0)
      inv.copy(items = items)
    }
  }

  fun removeItem(index: Int) {
    mutateInvoice { inv ->
      val items = inv.items.toMutableList().also { if (index in it.indices) it.removeAt(index) }
      val subtotal = items.sumOf { it.total }
      inv.copy(items = items, subtotal = subtotal, total = subtotal + inv.tax)
    }
  }

  /** [percent] is a rate like 16.0 meaning 16%. Recomputes tax amount and total. */
  fun updateTaxPercent(percent: Double) {
    mutateInvoice { inv ->
      val taxAmount = inv.subtotal * percent / 100.0
      inv.copy(taxPercent = percent, tax = taxAmount, total = inv.subtotal + taxAmount)
    }
  }

  private fun mutateInvoice(transform: (InvoiceData) -> InvoiceData) {
    _uiState.update { state ->
      state.invoice?.let { state.copy(invoice = transform(it)) } ?: state
    }
  }

  // ---------------------------------------------------------------------------
  // Save invoice + generate PDF
  // ---------------------------------------------------------------------------

  fun saveAndGeneratePdf() {
    val invoice = _uiState.value.invoice ?: return
    _uiState.update { it.copy(state = ExtractionState.SAVING) }

    viewModelScope.launch(Dispatchers.IO) {
      try {
        val profile = profileRepo.get()
        // Save JSON record first (without PDF path)
        val saved = repo.save(invoice)
        // Generate PDF
        val pdfFile = pdfGen.generate(invoice, profile, saved.id)
        // Update record with PDF path
        repo.updatePdfPath(saved.id, pdfFile.absolutePath)

        _uiState.update {
          it.copy(
            state = ExtractionState.SAVED,
            pdfPath = pdfFile.absolutePath,
            savedId = saved.id,
          )
        }
      } catch (e: Exception) {
        Log.e(TAG, "PDF generation failed", e)
        _uiState.update { it.copy(state = ExtractionState.ERROR, error = "Failed to generate PDF: ${e.message}") }
      }
    }
  }

  fun shareViaWhatsApp(context: Context) {
    val pdfPath = _uiState.value.pdfPath
    if (pdfPath.isEmpty()) return
    val file = File(pdfPath)
    if (!file.exists()) return

    val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
    val clientName = _uiState.value.invoice?.clientName?.ifEmpty { "invoice" } ?: "invoice"

    // Try WhatsApp first, fall back to system share sheet
    val whatsappIntent = Intent(Intent.ACTION_SEND).apply {
      type = "application/pdf"
      setPackage("com.whatsapp")
      putExtra(Intent.EXTRA_STREAM, uri)
      putExtra(Intent.EXTRA_TEXT, "Please find your invoice attached.")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    val shareIntent = Intent(Intent.ACTION_SEND).apply {
      type = "application/pdf"
      putExtra(Intent.EXTRA_STREAM, uri)
      putExtra(Intent.EXTRA_SUBJECT, "Invoice – $clientName")
      putExtra(Intent.EXTRA_TEXT, "Please find your invoice attached.")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    val chooser = Intent.createChooser(shareIntent, "Share invoice via…").apply {
      putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(whatsappIntent))
    }
    context.startActivity(chooser)
  }

  fun reset() {
    _uiState.update { InvoiceExtractionUiState() }
  }

  // ---------------------------------------------------------------------------
  // Prompt
  // ---------------------------------------------------------------------------

  private fun buildPrompt(today: String): String = """
    Listen carefully to the audio recording. The speaker is describing a sale in English, Swahili, or a mix of both.

    Extract the invoice details and return ONLY a valid JSON object — no explanation, no markdown, no code fences. Just the raw JSON.

    JSON structure:
    {
      "client_name": "string or null if not mentioned",
      "date": "$today",
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
    - If date not stated, use today: $today
    - Swahili number words: moja=1, mbili=2, tatu=3, nne=4, tano=5, sita=6, saba=7, nane=8, tisa=9, kumi=10
    - Return ONLY the JSON, nothing else
  """.trimIndent()

  // ---------------------------------------------------------------------------
  // JSON parsing
  // ---------------------------------------------------------------------------

  private fun parseInvoice(raw: String, today: String): InvoiceData {
    val cleaned = raw
      .removePrefix("```json").removePrefix("```")
      .removeSuffix("```").trim()

    return try {
      val dto = gson.fromJson(cleaned, InvoiceDto::class.java)
      val subtotal = dto.subtotal ?: 0.0
      val taxAmount = dto.tax ?: 0.0
      // Convert Gemma's flat tax amount → percentage so the UI shows a rate.
      val taxPercent = if (subtotal > 0.0) (taxAmount / subtotal * 100.0) else 0.0
      InvoiceData(
        clientName = dto.client_name ?: "",
        date = dto.date ?: today,
        items = dto.items?.map { item ->
          InvoiceLineItem(
            description = item.description ?: "",
            qty = item.qty ?: 1.0,
            unitPrice = item.unit_price ?: 0.0,
            total = item.total ?: ((item.qty ?: 1.0) * (item.unit_price ?: 0.0)),
          )
        } ?: emptyList(),
        subtotal = subtotal,
        taxPercent = taxPercent,
        tax = taxAmount,
        total = dto.total ?: (subtotal + taxAmount),
        currency = dto.currency ?: "KES",
        notes = dto.notes ?: "",
      )
    } catch (e: JsonSyntaxException) {
      Log.w(TAG, "Failed to parse invoice JSON: ${e.message}")
      InvoiceData.empty()
    }
  }

  // ---------------------------------------------------------------------------
  // PCM → WAV
  // ---------------------------------------------------------------------------

  private fun pcmToWav(pcmBytes: ByteArray): ByteArray {
    val sampleRate = 16000
    val channels = 1
    val bitsPerSample = 16
    val byteRate = sampleRate * channels * bitsPerSample / 8
    val blockAlign = channels * bitsPerSample / 8
    val dataSize = pcmBytes.size
    val headerSize = 44
    val wav = ByteArray(headerSize + dataSize)
    val totalSize = headerSize + dataSize - 8

    fun writeInt(arr: ByteArray, offset: Int, value: Int) {
      arr[offset] = (value and 0xFF).toByte()
      arr[offset + 1] = ((value shr 8) and 0xFF).toByte()
      arr[offset + 2] = ((value shr 16) and 0xFF).toByte()
      arr[offset + 3] = ((value shr 24) and 0xFF).toByte()
    }
    fun writeShort(arr: ByteArray, offset: Int, value: Int) {
      arr[offset] = (value and 0xFF).toByte()
      arr[offset + 1] = ((value shr 8) and 0xFF).toByte()
    }

    "RIFF".toByteArray().copyInto(wav, 0)
    writeInt(wav, 4, totalSize)
    "WAVE".toByteArray().copyInto(wav, 8)
    "fmt ".toByteArray().copyInto(wav, 12)
    writeInt(wav, 16, 16)
    writeShort(wav, 20, 1)
    writeShort(wav, 22, channels)
    writeInt(wav, 24, sampleRate)
    writeInt(wav, 28, byteRate)
    writeShort(wav, 32, blockAlign)
    writeShort(wav, 34, bitsPerSample)
    "data".toByteArray().copyInto(wav, 36)
    writeInt(wav, 40, dataSize)
    pcmBytes.copyInto(wav, 44)
    return wav
  }
}

// ---------------------------------------------------------------------------
// Gson DTOs
// ---------------------------------------------------------------------------

private data class ItemDto(
  val description: String?,
  val qty: Double?,
  val unit_price: Double?,
  val total: Double?,
)

private data class InvoiceDto(
  val client_name: String?,
  val date: String?,
  val items: List<ItemDto>?,
  val subtotal: Double?,
  val tax: Double?,
  val total: Double?,
  val currency: String?,
  val notes: String?,
)
