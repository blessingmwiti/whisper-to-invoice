package com.google.ai.edge.gallery.customtasks.invoiceextraction

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import com.google.ai.edge.gallery.data.Model
import com.google.ai.edge.gallery.data.Task
import com.google.ai.edge.gallery.ui.common.chat.AudioRecorderPanel

@Composable
fun InvoiceExtractionScreen(
  task: Task,
  model: Model,
  bottomPadding: Dp,
  viewModel: InvoiceExtractionViewModel = hiltViewModel(),
) {
  val uiState by viewModel.uiState.collectAsState()
  var isRecording by remember { mutableStateOf(false) }
  var amplitude by remember { mutableStateOf(0) }

  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(bottom = bottomPadding),
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    when (uiState.state) {
      ExtractionState.IDLE -> IdleContent(
        task = task,
        isRecording = isRecording,
        onAmplitudeChanged = { amplitude = it },
        onAudioRecorded = { pcmBytes ->
          isRecording = false
          viewModel.extractInvoice(model = model, audioPcmBytes = pcmBytes)
        },
        onRecordingStateChanged = { isRecording = it },
      )

      ExtractionState.PROCESSING -> ProcessingContent()

      ExtractionState.DONE -> uiState.invoice?.let { invoice ->
        InvoiceResultContent(
          invoice = invoice,
          onReset = { viewModel.reset() },
        )
      }

      ExtractionState.ERROR -> ErrorContent(
        error = uiState.error,
        onRetry = { viewModel.reset() },
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Idle — record button
// ---------------------------------------------------------------------------

@Composable
private fun IdleContent(
  task: Task,
  isRecording: Boolean,
  onAmplitudeChanged: (Int) -> Unit,
  onAudioRecorded: (ByteArray) -> Unit,
  onRecordingStateChanged: (Boolean) -> Unit,
) {
  Column(
    modifier = Modifier.fillMaxSize().padding(24.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text(
      text = "Whisper to Invoice",
      style = MaterialTheme.typography.headlineSmall,
      fontWeight = FontWeight.Bold,
    )
    Spacer(modifier = Modifier.height(8.dp))
    Text(
      text = "Speak your sale — Gemma 4 will build the invoice",
      style = MaterialTheme.typography.bodyMedium,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
    )
    Spacer(modifier = Modifier.height(8.dp))
    Text(
      text = "English · Swahili · Mix ya vyote viwili ✓",
      style = MaterialTheme.typography.labelSmall,
      color = MaterialTheme.colorScheme.primary,
    )
    Spacer(modifier = Modifier.height(40.dp))

    // AudioRecorderPanel already handles permissions + recording lifecycle
    AudioRecorderPanel(
      task = task,
      onAmplitudeChanged = onAmplitudeChanged,
      onSendAudioClip = { bytes ->
        onRecordingStateChanged(false)
        onAudioRecorded(bytes)
      },
      onClose = { onRecordingStateChanged(false) },
      modifier = Modifier.fillMaxWidth(),
    )

    Spacer(modifier = Modifier.height(24.dp))
    Text(
      text = "Example: \"Niliuza John nyanya kilo tatu, bei mia moja kila kilo, na vitunguu viwili mia tano\"",
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(horizontal = 16.dp),
    )
  }
}

// ---------------------------------------------------------------------------
// Processing spinner
// ---------------------------------------------------------------------------

@Composable
private fun ProcessingContent() {
  Column(
    modifier = Modifier.fillMaxSize(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    CircularProgressIndicator(modifier = Modifier.size(56.dp))
    Spacer(modifier = Modifier.height(24.dp))
    Text(
      text = "Gemma 4 is reading your sale…",
      style = MaterialTheme.typography.bodyLarge,
    )
    Spacer(modifier = Modifier.height(8.dp))
    Text(
      text = "This runs 100% on-device",
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}

// ---------------------------------------------------------------------------
// Invoice result
// ---------------------------------------------------------------------------

@Composable
private fun InvoiceResultContent(
  invoice: InvoiceData,
  onReset: () -> Unit,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .verticalScroll(rememberScrollState())
      .padding(16.dp),
  ) {
    Text(
      text = "Invoice Preview",
      style = MaterialTheme.typography.titleLarge,
      fontWeight = FontWeight.Bold,
    )
    Spacer(modifier = Modifier.height(4.dp))
    Text(
      text = "Review and proceed to generate PDF",
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Spacer(modifier = Modifier.height(16.dp))

    // Client + date
    Card(
      modifier = Modifier.fillMaxWidth(),
      colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
      Column(modifier = Modifier.padding(16.dp)) {
        InvoiceField("Client", invoice.clientName.ifEmpty { "—" })
        Spacer(modifier = Modifier.height(8.dp))
        InvoiceField("Date", invoice.date)
        Spacer(modifier = Modifier.height(8.dp))
        InvoiceField("Currency", invoice.currency)
      }
    }

    Spacer(modifier = Modifier.height(12.dp))

    // Line items
    Card(
      modifier = Modifier.fillMaxWidth(),
      colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
      Column(modifier = Modifier.padding(16.dp)) {
        Text("Items", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(8.dp))

        if (invoice.items.isEmpty()) {
          Text(
            "No items extracted — try recording again",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
          )
        } else {
          invoice.items.forEachIndexed { index, item ->
            if (index > 0) Spacer(modifier = Modifier.height(8.dp))
            Row(
              modifier = Modifier.fillMaxWidth(),
              horizontalArrangement = Arrangement.SpaceBetween,
            ) {
              Column(modifier = Modifier.weight(1f)) {
                Text(item.description, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                Text(
                  "${item.qty}× ${invoice.currency} ${"%,.2f".format(item.unitPrice)}",
                  style = MaterialTheme.typography.bodySmall,
                  color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
              }
              Text(
                "${invoice.currency} ${"%,.2f".format(item.total)}",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
              )
            }
          }
        }
      }
    }

    Spacer(modifier = Modifier.height(12.dp))

    // Totals
    Card(
      modifier = Modifier.fillMaxWidth(),
      colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
      Column(modifier = Modifier.padding(16.dp)) {
        TotalRow("Subtotal", invoice.currency, invoice.subtotal)
        TotalRow("Tax", invoice.currency, invoice.tax)
        Spacer(modifier = Modifier.height(4.dp))
        TotalRow("TOTAL", invoice.currency, invoice.total, bold = true)
      }
    }

    Spacer(modifier = Modifier.height(24.dp))

    // Actions — PDF + Reset (WhatsApp share comes in Phase 4)
    Button(
      onClick = { /* TODO Phase 4: generate PDF */ },
      modifier = Modifier.fillMaxWidth(),
    ) {
      Text("Generate PDF")
    }
    Spacer(modifier = Modifier.height(8.dp))
    Button(
      onClick = onReset,
      modifier = Modifier.fillMaxWidth(),
    ) {
      Icon(Icons.Rounded.Refresh, contentDescription = null)
      Spacer(modifier = Modifier.size(8.dp))
      Text("New Invoice")
    }
  }
}

@Composable
private fun ErrorContent(error: String, onRetry: () -> Unit) {
  Column(
    modifier = Modifier.fillMaxSize().padding(24.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text("Something went wrong", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.error)
    Spacer(modifier = Modifier.height(8.dp))
    Text(error, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
    Spacer(modifier = Modifier.height(24.dp))
    Button(onClick = onRetry) { Text("Try again") }
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

@Composable
private fun InvoiceField(label: String, value: String) {
  Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
    Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
  }
}

@Composable
private fun TotalRow(label: String, currency: String, amount: Double, bold: Boolean = false) {
  Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
    Text(
      label,
      style = if (bold) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyMedium,
      fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
    )
    Text(
      "$currency ${"%,.2f".format(amount)}",
      style = if (bold) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyMedium,
      fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal,
    )
  }
}
