package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.ai.edge.gallery.data.Model
import com.google.ai.edge.gallery.ui.llmchat.LlmChatModelHelper
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val TAG = "InvoiceExtractionVM"

enum class ExtractionState {
  IDLE,       // waiting for user to record
  PROCESSING, // Gemma 4 is running
  DONE,       // invoice extracted successfully
  ERROR,      // something went wrong
}

data class InvoiceExtractionUiState(
  val state: ExtractionState = ExtractionState.IDLE,
  val invoice: InvoiceData? = null,
  val rawResponse: String = "",
  val error: String = "",
)

@HiltViewModel
class InvoiceExtractionViewModel @Inject constructor() : ViewModel() {

  private val _uiState = MutableStateFlow(InvoiceExtractionUiState())
  val uiState = _uiState.asStateFlow()

  private val gson = Gson()

  /** Call this when the user finishes recording. Sends audio to Gemma 4. */
  fun extractInvoice(model: Model, audioPcmBytes: ByteArray) {
    _uiState.update { it.copy(state = ExtractionState.PROCESSING, error = "", rawResponse = "") }

    viewModelScope.launch(Dispatchers.Default) {
      // Wait for model to be ready (it's initialized by the framework before this screen opens)
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
            Log.d(TAG, "Gemma raw response: $raw")
            val invoice = parseInvoice(raw, today)
            _uiState.update {
              it.copy(
                state = ExtractionState.DONE,
                invoice = invoice,
                rawResponse = raw,
              )
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

  fun reset() {
    _uiState.update { InvoiceExtractionUiState() }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
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

  private fun parseInvoice(raw: String, today: String): InvoiceData {
    // Strip markdown code fences if Gemma adds them despite instructions
    val cleaned = raw
      .removePrefix("```json").removePrefix("```")
      .removeSuffix("```").trim()

    return try {
      val dto = gson.fromJson(cleaned, InvoiceDto::class.java)
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
        subtotal = dto.subtotal ?: 0.0,
        tax = dto.tax ?: 0.0,
        total = dto.total ?: 0.0,
        currency = dto.currency ?: "KES",
        notes = dto.notes ?: "",
      )
    } catch (e: JsonSyntaxException) {
      Log.w(TAG, "Failed to parse invoice JSON: ${e.message}")
      InvoiceData.empty()
    }
  }

  // ---------------------------------------------------------------------------
  // PCM → WAV conversion (LiteRT expects WAV format)
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

    // RIFF header
    "RIFF".toByteArray().copyInto(wav, 0)
    writeInt(wav, 4, totalSize)
    "WAVE".toByteArray().copyInto(wav, 8)
    // fmt chunk
    "fmt ".toByteArray().copyInto(wav, 12)
    writeInt(wav, 16, 16)           // chunk size
    writeShort(wav, 20, 1)          // PCM format
    writeShort(wav, 22, channels)
    writeInt(wav, 24, sampleRate)
    writeInt(wav, 28, byteRate)
    writeShort(wav, 32, blockAlign)
    writeShort(wav, 34, bitsPerSample)
    // data chunk
    "data".toByteArray().copyInto(wav, 36)
    writeInt(wav, 40, dataSize)
    pcmBytes.copyInto(wav, 44)

    return wav
  }
}

// ---------------------------------------------------------------------------
// Gson DTO — mirrors the JSON the prompt requests
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
