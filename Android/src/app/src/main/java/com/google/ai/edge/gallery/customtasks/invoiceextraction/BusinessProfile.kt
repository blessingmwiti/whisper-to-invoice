package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.content.Context
import android.net.Uri
import androidx.core.content.edit
import java.io.File
import java.io.FileOutputStream

data class BusinessProfile(
  val businessName: String = "",
  val tagline: String = "",
  val address: String = "",
  val phone: String = "",
  val email: String = "",
  val paymentInstructions: String = "",
  /** Absolute path to a logo PNG copied into app internal storage. Empty = no logo. */
  val logoPath: String = "",
) {
  val isEmpty: Boolean get() = businessName.isBlank()
}

class BusinessProfileRepository(context: Context) {
  private val prefs = context.getSharedPreferences("business_profile", Context.MODE_PRIVATE)
  private val logoDir = File(context.filesDir, "logo").also { it.mkdirs() }

  fun get(): BusinessProfile = BusinessProfile(
    businessName        = prefs.getString("businessName", "") ?: "",
    tagline             = prefs.getString("tagline", "") ?: "",
    address             = prefs.getString("address", "") ?: "",
    phone               = prefs.getString("phone", "") ?: "",
    email               = prefs.getString("email", "") ?: "",
    paymentInstructions = prefs.getString("paymentInstructions", "") ?: "",
    logoPath            = prefs.getString("logoPath", "") ?: "",
  )

  fun save(profile: BusinessProfile) {
    prefs.edit {
      putString("businessName",        profile.businessName)
      putString("tagline",             profile.tagline)
      putString("address",             profile.address)
      putString("phone",               profile.phone)
      putString("email",               profile.email)
      putString("paymentInstructions", profile.paymentInstructions)
      putString("logoPath",            profile.logoPath)
    }
  }

  /**
   * Copy a content URI (from the image picker) into internal storage and return the new path.
   * Call this on a background thread.
   */
  fun importLogo(context: Context, uri: Uri): String {
    val dest = File(logoDir, "logo.png")
    context.contentResolver.openInputStream(uri)?.use { input ->
      FileOutputStream(dest).use { output -> input.copyTo(output) }
    }
    return dest.absolutePath
  }
}
