/*
 * Stub Analytics — Firebase removed. All logEvent calls are null-safe no-ops.
 */
package com.google.ai.edge.gallery

import android.os.Bundle

/** No-op analytics stub. firebaseAnalytics is always null so no events are ever sent. */
class AnalyticsStub {
  fun logEvent(name: String, params: Bundle? = null) {
    // no-op
  }
}

/** Always null — no analytics in Whisper to Invoice. */
val firebaseAnalytics: AnalyticsStub? = null

/** Event names kept for source compatibility; no events are actually sent. */
enum class GalleryEvent(val id: String) {
  CAPABILITY_SELECT("capability_select"),
  GENERATE_ACTION("generate_action"),
  SKILL_EXECUTION("skill_execution"),
  SKILL_MANAGEMENT("skill_management"),
  BUTTON_CLICKED("button_clicked"),
  MODEL_DOWNLOAD("model_download"),
}
