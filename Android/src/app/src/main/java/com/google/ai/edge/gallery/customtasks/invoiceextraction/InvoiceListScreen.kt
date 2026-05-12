package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.content.Context
import android.content.Intent
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Receipt
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.PictureAsPdf
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceListScreen(onNavigateUp: () -> Unit) {
  val context = LocalContext.current
  val repo = remember { InvoiceRepository(context) }
  val scope = rememberCoroutineScope()

  var invoices by remember { mutableStateOf<List<SavedInvoice>>(emptyList()) }
  var deleteTarget by remember { mutableStateOf<SavedInvoice?>(null) }

  fun reload() {
    scope.launch(Dispatchers.IO) {
      val list = repo.listAll()
      withContext(Dispatchers.Main) { invoices = list }
    }
  }

  LaunchedEffect(Unit) { reload() }

  Scaffold(
    topBar = {
      CenterAlignedTopAppBar(
        title = { Text("My Invoices") },
        navigationIcon = {
          IconButton(onClick = onNavigateUp) {
            Icon(Icons.Rounded.ArrowBack, contentDescription = "Back")
          }
        },
      )
    }
  ) { innerPadding ->
    if (invoices.isEmpty()) {
      Box(
        modifier = Modifier.fillMaxSize().padding(innerPadding),
        contentAlignment = Alignment.Center,
      ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
          Icon(
            Icons.Outlined.Receipt,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
          )
          Spacer(modifier = Modifier.height(12.dp))
          Text(
            "No invoices yet",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
          )
          Text(
            "Speak a sale to create your first invoice",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
          )
        }
      }
    } else {
      LazyColumn(
        modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 12.dp),
      ) {
        items(invoices, key = { it.id }) { saved ->
          InvoiceCard(
            saved = saved,
            onShare = { sharePdf(context, saved) },
            onDelete = { deleteTarget = saved },
          )
        }
      }
    }
  }

  // Delete confirmation dialog
  deleteTarget?.let { target ->
    AlertDialog(
      onDismissRequest = { deleteTarget = null },
      title = { Text("Delete invoice?") },
      text = {
        val client = target.invoice.clientName.ifEmpty { "Unknown client" }
        Text("Delete invoice for \"$client\" dated ${target.invoice.date}? This cannot be undone.")
      },
      confirmButton = {
        TextButton(onClick = {
          scope.launch(Dispatchers.IO) {
            repo.delete(target.id)
            withContext(Dispatchers.Main) {
              deleteTarget = null
              reload()
            }
          }
        }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
      },
      dismissButton = {
        TextButton(onClick = { deleteTarget = null }) { Text("Cancel") }
      },
    )
  }
}

@Composable
private fun InvoiceCard(
  saved: SavedInvoice,
  onShare: () -> Unit,
  onDelete: () -> Unit,
) {
  val dateStr = remember(saved.createdAt) {
    SimpleDateFormat("dd MMM yyyy · HH:mm", Locale.getDefault()).format(Date(saved.createdAt))
  }
  val hasPdf = saved.pdfPath.isNotEmpty() && File(saved.pdfPath).exists()

  Card(
    modifier = Modifier.fillMaxWidth(),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
  ) {
    Row(
      modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      // Info
      Column(modifier = Modifier.weight(1f)) {
        Text(
          text = saved.invoice.clientName.ifEmpty { "Unknown client" },
          style = MaterialTheme.typography.titleSmall,
          fontWeight = FontWeight.SemiBold,
        )
        Text(
          text = dateStr,
          style = MaterialTheme.typography.bodySmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
          text = "${saved.invoice.currency} ${"%,.2f".format(saved.invoice.total)}",
          style = MaterialTheme.typography.bodyMedium,
          fontWeight = FontWeight.Medium,
          color = MaterialTheme.colorScheme.primary,
        )
      }

      // Actions
      if (hasPdf) {
        IconButton(onClick = onShare) {
          Icon(Icons.Rounded.Share, contentDescription = "Share PDF")
        }
      } else {
        Icon(
          Icons.Rounded.PictureAsPdf,
          contentDescription = null,
          tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
          modifier = Modifier.size(24.dp).padding(4.dp),
        )
      }
      IconButton(onClick = onDelete) {
        Icon(
          Icons.Rounded.Delete,
          contentDescription = "Delete",
          tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f),
        )
      }
    }
  }
}

private fun sharePdf(context: Context, saved: SavedInvoice) {
  val file = File(saved.pdfPath)
  if (!file.exists()) return
  val uri = FileProvider.getUriForFile(
    context,
    "${context.packageName}.provider",
    file,
  )
  val client = saved.invoice.clientName.ifEmpty { "invoice" }
  val intent = Intent(Intent.ACTION_SEND).apply {
    type = "application/pdf"
    putExtra(Intent.EXTRA_STREAM, uri)
    putExtra(Intent.EXTRA_SUBJECT, "Invoice – $client")
    putExtra(Intent.EXTRA_TEXT, "Please find your invoice attached.")
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
  }
  context.startActivity(Intent.createChooser(intent, "Share invoice via…"))
}
