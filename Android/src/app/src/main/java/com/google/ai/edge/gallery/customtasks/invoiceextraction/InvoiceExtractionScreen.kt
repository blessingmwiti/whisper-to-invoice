package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.PictureAsPdf
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
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
  val context = LocalContext.current

  Column(
    modifier = Modifier
      .fillMaxSize()
      .padding(bottom = bottomPadding),
    horizontalAlignment = Alignment.CenterHorizontally,
  ) {
    when (uiState.state) {
      ExtractionState.IDLE -> IdleContent(
        task = task,
        onAudioRecorded = { pcmBytes -> viewModel.extractInvoice(model = model, audioPcmBytes = pcmBytes) },
      )

      ExtractionState.PROCESSING -> ProcessingContent()

      ExtractionState.DONE -> uiState.invoice?.let { invoice ->
        InvoiceResultContent(
          invoice = invoice,
          onClientChanged = { viewModel.updateClient(it) },
          onDateChanged = { viewModel.updateDate(it) },
          onNotesChanged = { viewModel.updateNotes(it) },
          onCurrencyChanged = { viewModel.updateCurrency(it) },
          onItemChanged = { idx, item -> viewModel.updateItem(idx, item) },
          onItemRemoved = { idx -> viewModel.removeItem(idx) },
          onAddItem = { viewModel.addItem() },
          onTaxChanged = { viewModel.updateTax(it) },
          onSave = { viewModel.saveAndGeneratePdf() },
          onReset = { viewModel.reset() },
          isSaving = false,
        )
      }

      ExtractionState.SAVING -> SavingContent()

      ExtractionState.SAVED -> uiState.invoice?.let { invoice ->
        InvoiceResultContent(
          invoice = invoice,
          onClientChanged = { viewModel.updateClient(it) },
          onDateChanged = { viewModel.updateDate(it) },
          onNotesChanged = { viewModel.updateNotes(it) },
          onCurrencyChanged = { viewModel.updateCurrency(it) },
          onItemChanged = { idx, item -> viewModel.updateItem(idx, item) },
          onItemRemoved = { idx -> viewModel.removeItem(idx) },
          onAddItem = { viewModel.addItem() },
          onTaxChanged = { viewModel.updateTax(it) },
          onSave = { viewModel.saveAndGeneratePdf() },
          onReset = { viewModel.reset() },
          isSaving = false,
          pdfReady = true,
          onShare = { viewModel.shareViaWhatsApp(context) },
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
// Idle
// ---------------------------------------------------------------------------

@Composable
private fun IdleContent(task: Task, onAudioRecorded: (ByteArray) -> Unit) {
  val context = LocalContext.current

  var micPermissionGranted by remember {
    mutableStateOf(
      ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
        == PackageManager.PERMISSION_GRANTED
    )
  }

  val permissionLauncher = rememberLauncherForActivityResult(
    contract = ActivityResultContracts.RequestPermission()
  ) { granted -> micPermissionGranted = granted }

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

    if (micPermissionGranted) {
      AudioRecorderPanel(
        task = task,
        onAmplitudeChanged = {},
        onSendAudioClip = { bytes -> onAudioRecorded(bytes) },
        onClose = {},
        modifier = Modifier.fillMaxWidth(),
      )
    } else {
      Button(onClick = { permissionLauncher.launch(Manifest.permission.RECORD_AUDIO) }) {
        Icon(Icons.Rounded.Mic, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text("Allow microphone access")
      }
      Spacer(modifier = Modifier.height(8.dp))
      Text(
        text = "Microphone access is required to record your sale",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
      )
    }

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
// Processing
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
    Text("Gemma 4 is reading your sale…", style = MaterialTheme.typography.bodyLarge)
    Spacer(modifier = Modifier.height(8.dp))
    Text(
      "This runs 100% on-device",
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
  }
}

// ---------------------------------------------------------------------------
// Saving
// ---------------------------------------------------------------------------

@Composable
private fun SavingContent() {
  Column(
    modifier = Modifier.fillMaxSize(),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    CircularProgressIndicator(modifier = Modifier.size(48.dp))
    Spacer(modifier = Modifier.height(16.dp))
    Text("Generating PDF…", style = MaterialTheme.typography.bodyLarge)
  }
}

// ---------------------------------------------------------------------------
// Invoice result — fully editable
// ---------------------------------------------------------------------------

@Composable
private fun InvoiceResultContent(
  invoice: InvoiceData,
  onClientChanged: (String) -> Unit,
  onDateChanged: (String) -> Unit,
  onNotesChanged: (String) -> Unit,
  onCurrencyChanged: (String) -> Unit,
  onItemChanged: (Int, InvoiceLineItem) -> Unit,
  onItemRemoved: (Int) -> Unit,
  onAddItem: () -> Unit,
  onTaxChanged: (Double) -> Unit,
  onSave: () -> Unit,
  onReset: () -> Unit,
  isSaving: Boolean,
  pdfReady: Boolean = false,
  onShare: (() -> Unit)? = null,
) {
  Column(
    modifier = Modifier
      .fillMaxSize()
      .verticalScroll(rememberScrollState())
      .padding(16.dp),
  ) {
    Row(
      modifier = Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.SpaceBetween,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(
        text = "Invoice Preview",
        style = MaterialTheme.typography.titleLarge,
        fontWeight = FontWeight.Bold,
      )
      TextButton(onClick = onReset) {
        Icon(Icons.Rounded.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(modifier = Modifier.width(4.dp))
        Text("New")
      }
    }
    Text(
      text = "Tap any field to edit before saving",
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Spacer(modifier = Modifier.height(16.dp))

    // --- Client + date + currency ---
    Card(
      modifier = Modifier.fillMaxWidth(),
      colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
      Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
          value = invoice.clientName,
          onValueChange = onClientChanged,
          label = { Text("Client name") },
          modifier = Modifier.fillMaxWidth(),
          singleLine = true,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
          OutlinedTextField(
            value = invoice.date,
            onValueChange = onDateChanged,
            label = { Text("Date") },
            modifier = Modifier.weight(1f),
            singleLine = true,
          )
          OutlinedTextField(
            value = invoice.currency,
            onValueChange = onCurrencyChanged,
            label = { Text("Currency") },
            modifier = Modifier.width(90.dp),
            singleLine = true,
          )
        }
      }
    }

    Spacer(modifier = Modifier.height(12.dp))

    // --- Line items ---
    Card(
      modifier = Modifier.fillMaxWidth(),
      colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
      Column(modifier = Modifier.padding(16.dp)) {
        Row(
          modifier = Modifier.fillMaxWidth(),
          horizontalArrangement = Arrangement.SpaceBetween,
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text("Items", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
          TextButton(onClick = onAddItem) {
            Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("Add item")
          }
        }
        Spacer(modifier = Modifier.height(8.dp))

        if (invoice.items.isEmpty()) {
          Text(
            "No items — tap \"Add item\" or record again",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
          )
        } else {
          invoice.items.forEachIndexed { index, item ->
            if (index > 0) {
              HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            }
            LineItemEditor(
              item = item,
              currency = invoice.currency,
              onChanged = { updated -> onItemChanged(index, updated) },
              onRemove = { onItemRemoved(index) },
            )
          }
        }
      }
    }

    Spacer(modifier = Modifier.height(12.dp))

    // --- Totals ---
    Card(
      modifier = Modifier.fillMaxWidth(),
      colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
      Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        TotalRow("Subtotal", invoice.currency, invoice.subtotal)
        Row(verticalAlignment = Alignment.CenterVertically) {
          Text(
            "Tax",
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
          )
          OutlinedTextField(
            value = if (invoice.tax == 0.0) "" else invoice.tax.toString(),
            onValueChange = { onTaxChanged(it.toDoubleOrNull() ?: 0.0) },
            label = { Text(invoice.currency) },
            modifier = Modifier.width(120.dp),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
          )
        }
        HorizontalDivider()
        TotalRowBold("TOTAL", invoice.currency, invoice.total)
      }
    }

    Spacer(modifier = Modifier.height(12.dp))

    // --- Notes ---
    OutlinedTextField(
      value = invoice.notes,
      onValueChange = onNotesChanged,
      label = { Text("Notes (optional)") },
      modifier = Modifier.fillMaxWidth(),
      minLines = 2,
      maxLines = 4,
    )

    Spacer(modifier = Modifier.height(24.dp))

    // --- Action buttons ---
    if (pdfReady && onShare != null) {
      Button(
        onClick = onShare,
        modifier = Modifier.fillMaxWidth(),
      ) {
        Icon(Icons.Rounded.Share, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text("Share via WhatsApp")
      }
      Spacer(modifier = Modifier.height(8.dp))
      FilledTonalButton(
        onClick = onSave,
        modifier = Modifier.fillMaxWidth(),
        enabled = !isSaving,
      ) {
        Icon(Icons.Rounded.PictureAsPdf, contentDescription = null)
        Spacer(modifier = Modifier.width(8.dp))
        Text("Regenerate PDF")
      }
    } else {
      Button(
        onClick = onSave,
        modifier = Modifier.fillMaxWidth(),
        enabled = !isSaving,
      ) {
        if (isSaving) {
          CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
          Spacer(modifier = Modifier.width(8.dp))
        } else {
          Icon(Icons.Rounded.PictureAsPdf, contentDescription = null)
          Spacer(modifier = Modifier.width(8.dp))
        }
        Text("Generate PDF & Save")
      }
    }

    Spacer(modifier = Modifier.height(16.dp))
  }
}

// ---------------------------------------------------------------------------
// Line item editor row
// ---------------------------------------------------------------------------

@Composable
private fun LineItemEditor(
  item: InvoiceLineItem,
  currency: String,
  onChanged: (InvoiceLineItem) -> Unit,
  onRemove: () -> Unit,
) {
  Column {
    Row(verticalAlignment = Alignment.CenterVertically) {
      OutlinedTextField(
        value = item.description,
        onValueChange = { onChanged(item.copy(description = it)) },
        label = { Text("Description") },
        modifier = Modifier.weight(1f),
        singleLine = true,
      )
      IconButton(onClick = onRemove) {
        Icon(
          Icons.Rounded.Delete,
          contentDescription = "Remove item",
          tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f),
        )
      }
    }
    Spacer(modifier = Modifier.height(4.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      OutlinedTextField(
        value = if (item.qty == item.qty.toLong().toDouble()) item.qty.toLong().toString() else item.qty.toString(),
        onValueChange = { v ->
          val qty = v.toDoubleOrNull() ?: item.qty
          val total = qty * item.unitPrice
          onChanged(item.copy(qty = qty, total = total))
        },
        label = { Text("Qty") },
        modifier = Modifier.weight(1f),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
      )
      OutlinedTextField(
        value = if (item.unitPrice == 0.0) "" else item.unitPrice.toString(),
        onValueChange = { v ->
          val price = v.toDoubleOrNull() ?: item.unitPrice
          val total = item.qty * price
          onChanged(item.copy(unitPrice = price, total = total))
        },
        label = { Text("Unit price ($currency)") },
        modifier = Modifier.weight(2f),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
      )
    }
    Text(
      text = "Line total: $currency ${"%,.2f".format(item.total)}",
      style = MaterialTheme.typography.bodySmall,
      color = MaterialTheme.colorScheme.onSurfaceVariant,
      modifier = Modifier.padding(top = 2.dp),
    )
  }
}

// ---------------------------------------------------------------------------
// Total row helpers
// ---------------------------------------------------------------------------

@Composable
private fun TotalRow(label: String, currency: String, amount: Double) {
  Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
    Text(label, style = MaterialTheme.typography.bodyMedium)
    Text("$currency ${"%,.2f".format(amount)}", style = MaterialTheme.typography.bodyMedium)
  }
}

@Composable
private fun TotalRowBold(label: String, currency: String, amount: Double) {
  Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
    Text(label, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    Text(
      "$currency ${"%,.2f".format(amount)}",
      style = MaterialTheme.typography.titleSmall,
      fontWeight = FontWeight.Bold,
    )
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

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
