package com.google.ai.edge.gallery.ui.legal

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.ai.edge.gallery.R
import com.google.ai.edge.gallery.legal.LegalConstants
import com.google.ai.edge.gallery.ui.common.ClickableLink
import com.google.ai.edge.gallery.ui.common.MarkdownText
import com.google.android.gms.oss.licenses.OssLicensesMenuActivity

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(onNavigateUp: () -> Unit) {
  val context = LocalContext.current

  Scaffold(
    topBar = {
      TopAppBar(
        title = { Text(stringResource(R.string.about_screen_title)) },
        navigationIcon = {
          IconButton(onClick = onNavigateUp) {
            Icon(
              imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
              contentDescription = stringResource(R.string.cd_navigate_back_icon),
            )
          }
        },
      )
    },
  ) { innerPadding ->
    Column(
      modifier =
        Modifier
          .fillMaxSize()
          .padding(innerPadding)
          .verticalScroll(rememberScrollState())
          .padding(horizontal = 24.dp, vertical = 16.dp),
      verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
      SectionTitle(stringResource(R.string.about_section_app))
      Text(
        text = stringResource(R.string.about_app_description),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      Text(
        text =
          stringResource(
            R.string.about_developer_line,
            LegalConstants.DEVELOPER_NAME,
            LegalConstants.DEVELOPER_LOCATION,
          ),
        style = MaterialTheme.typography.bodyMedium,
      )
      ClickableLink(
        url = "mailto:${LegalConstants.DEVELOPER_EMAIL}",
        linkText = LegalConstants.DEVELOPER_EMAIL,
      )

      SectionTitle(stringResource(R.string.about_section_privacy))
      MarkdownText(
        text = stringResource(R.string.about_privacy_summary),
        smallFontSize = true,
        textColor = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      ClickableLink(
        url = LegalConstants.PRIVACY_POLICY_URL,
        linkText = stringResource(R.string.about_open_privacy_policy),
      )

      SectionTitle(stringResource(R.string.about_section_open_source))
      MarkdownText(
        text = stringResource(R.string.about_open_source_notice),
        smallFontSize = true,
        textColor = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      ClickableLink(
        url = LegalConstants.UPSTREAM_SOURCE_URL,
        linkText = stringResource(R.string.about_upstream_project_link),
      )
      ClickableLink(
        url = LegalConstants.APACHE_LICENSE_URL,
        linkText = stringResource(R.string.about_apache_license_link),
      )
      ClickableLink(
        url = LegalConstants.GEMMA_TERMS_URL,
        linkText = stringResource(R.string.tos_dialog_title_gemma),
      )
      OutlinedButton(
        onClick = {
          context.startActivity(Intent(context, OssLicensesMenuActivity::class.java))
        },
        modifier = Modifier.fillMaxWidth(),
      ) {
        Text(stringResource(R.string.about_view_oss_licenses))
      }

      SectionTitle(stringResource(R.string.about_section_ai))
      MarkdownText(
        text = stringResource(R.string.about_ai_disclosure),
        smallFontSize = true,
        textColor = MaterialTheme.colorScheme.onSurfaceVariant,
      )
      ClickableLink(
        url = LegalConstants.GEMMA_PROHIBITED_USE_URL,
        linkText = stringResource(R.string.settings_dialog_gemma_prohibited_use_policy),
      )
    }
  }
}

@Composable
private fun SectionTitle(title: String) {
  Text(
    text = title,
    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
  )
}
