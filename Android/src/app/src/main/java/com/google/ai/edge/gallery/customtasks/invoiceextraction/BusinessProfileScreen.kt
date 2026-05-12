package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AddPhotoAlternate
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BusinessProfileScreen(
  onNavigateUp: () -> Unit,
) {
  val context = LocalContext.current
  val repo = remember { BusinessProfileRepository(context) }
  val scope = rememberCoroutineScope()
  val snackbarHostState = remember { SnackbarHostState() }

  var profile by remember { mutableStateOf(BusinessProfile()) }

  // Load saved profile on first launch
  LaunchedEffect(Unit) {
    profile = withContext(Dispatchers.IO) { repo.get() }
  }

  // Image picker launcher
  val logoPickerLauncher = rememberLauncherForActivityResult(
    contract = ActivityResultContracts.GetContent()
  ) { uri: Uri? ->
    uri?.let {
      scope.launch(Dispatchers.IO) {
        val path = repo.importLogo(context, it)
        profile = profile.copy(logoPath = path)
      }
    }
  }

  Scaffold(
    snackbarHost = { SnackbarHost(snackbarHostState) },
    topBar = {
      CenterAlignedTopAppBar(
        title = { Text("Business Profile") },
        navigationIcon = {
          IconButton(onClick = onNavigateUp) {
            Icon(Icons.Rounded.ArrowBack, contentDescription = "Back")
          }
        },
        actions = {
          IconButton(onClick = {
            scope.launch(Dispatchers.IO) {
              repo.save(profile)
              withContext(Dispatchers.Main) {
                snackbarHostState.showSnackbar("Profile saved")
              }
            }
          }) {
            Icon(Icons.Rounded.Check, contentDescription = "Save")
          }
        }
      )
    }
  ) { innerPadding ->
    Column(
      modifier = Modifier
        .fillMaxSize()
        .padding(innerPadding)
        .verticalScroll(rememberScrollState())
        .padding(horizontal = 16.dp, vertical = 8.dp),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {

      // Logo picker
      SectionLabel("Logo")
      LogoPicker(
        logoPath = profile.logoPath,
        onPickLogo = { logoPickerLauncher.launch("image/*") },
      )

      SectionLabel("Business Details")
      OutlinedTextField(
        value = profile.businessName,
        onValueChange = { profile = profile.copy(businessName = it) },
        label = { Text("Business name *") },
        placeholder = { Text("e.g. Acme General Store") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
      )
      OutlinedTextField(
        value = profile.tagline,
        onValueChange = { profile = profile.copy(tagline = it) },
        label = { Text("Tagline (optional)") },
        placeholder = { Text("e.g. Quality goods, fair prices") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
      )

      SectionLabel("Contact")
      OutlinedTextField(
        value = profile.address,
        onValueChange = { profile = profile.copy(address = it) },
        label = { Text("Address") },
        placeholder = { Text("e.g. 123 Main Street, Springfield") },
        modifier = Modifier.fillMaxWidth(),
        minLines = 2,
        maxLines = 3,
      )
      OutlinedTextField(
        value = profile.phone,
        onValueChange = { profile = profile.copy(phone = it) },
        label = { Text("Phone") },
        placeholder = { Text("e.g. +254 712 345 678") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
      )
      OutlinedTextField(
        value = profile.email,
        onValueChange = { profile = profile.copy(email = it) },
        label = { Text("Email (optional)") },
        placeholder = { Text("e.g. store@example.com") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
      )

      SectionLabel("Payment Instructions")
      OutlinedTextField(
        value = profile.paymentInstructions,
        onValueChange = { profile = profile.copy(paymentInstructions = it) },
        label = { Text("Payment details") },
        placeholder = { Text("e.g. M-Pesa: 0700 000 000 (John Doe)\nBank: First National Bank A/C: 1234567890") },
        modifier = Modifier.fillMaxWidth(),
        minLines = 3,
        maxLines = 6,
      )

      Spacer(modifier = Modifier.height(8.dp))

      FilledTonalButton(
        onClick = {
          scope.launch(Dispatchers.IO) {
            repo.save(profile)
            withContext(Dispatchers.Main) {
              snackbarHostState.showSnackbar("Profile saved")
            }
          }
        },
        modifier = Modifier.fillMaxWidth(),
      ) {
        Text("Save Profile")
      }

      Spacer(modifier = Modifier.height(16.dp))
    }
  }
}

@Composable
private fun SectionLabel(text: String) {
  Text(
    text = text,
    style = MaterialTheme.typography.labelLarge,
    fontWeight = FontWeight.SemiBold,
    color = MaterialTheme.colorScheme.primary,
    modifier = Modifier.padding(top = 8.dp),
  )
}

@Composable
private fun LogoPicker(
  logoPath: String,
  onPickLogo: () -> Unit,
) {
  Box(
    modifier = Modifier
      .size(96.dp)
      .clip(RoundedCornerShape(12.dp))
      .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(12.dp))
      .background(MaterialTheme.colorScheme.surfaceVariant)
      .clickable { onPickLogo() },
    contentAlignment = Alignment.Center,
  ) {
    val logoBitmap = remember(logoPath) {
      if (logoPath.isNotEmpty() && File(logoPath).exists())
        BitmapFactory.decodeFile(logoPath)?.asImageBitmap()
      else null
    }
    if (logoBitmap != null) {
      Image(
        bitmap = logoBitmap,
        contentDescription = "Business logo",
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxSize(),
      )
    } else {
      Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
          Icons.Outlined.AddPhotoAlternate,
          contentDescription = null,
          tint = MaterialTheme.colorScheme.onSurfaceVariant,
          modifier = Modifier.size(32.dp),
        )
        Text(
          "Add logo",
          style = MaterialTheme.typography.labelSmall,
          color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
      }
    }
  }
}
