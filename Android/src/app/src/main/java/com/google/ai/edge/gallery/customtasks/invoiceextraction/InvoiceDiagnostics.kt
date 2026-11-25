package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Debug
import android.util.Log

private const val TAG = "InvoiceDiag"

/**
 * Crash / memory diagnostics for the invoice flow.
 *
 * Only sizes, counters and Android system info are logged here — never invoice content, client
 * names or audio data.
 */
object InvoiceDiagnostics {

  /** Logs system RAM, process PSS and native/Java heap usage, tagged with [label]. */
  fun logMemory(context: Context, label: String) {
    try {
      val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
      val sys = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
      val proc = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
      val rt = Runtime.getRuntime()
      Log.d(
        TAG,
        "[$label] sysAvail=${sys.availMem.toMb()}MB sysTotal=${sys.totalMem.toMb()}MB " +
          "lowMemory=${sys.lowMemory} lowThreshold=${sys.threshold.toMb()}MB | " +
          "procPss=${proc.totalPss / 1024}MB nativePss=${proc.nativePss / 1024}MB " +
          "javaPss=${proc.dalvikPss / 1024}MB graphicsPss=" +
          "${proc.getMemoryStat("summary.graphics").toIntOrNull()?.div(1024) ?: -1}MB | " +
          "nativeHeapAlloc=${Debug.getNativeHeapAllocatedSize().toMb()}MB " +
          "javaHeapUsed=${(rt.totalMemory() - rt.freeMemory()).toMb()}MB " +
          "javaHeapMax=${rt.maxMemory().toMb()}MB",
      )
    } catch (e: Exception) {
      Log.w(TAG, "[$label] failed to read memory info", e)
    }
  }

  /**
   * Logs why the previous app processes ended (crash, native crash, low memory kill, signal...).
   * Android keeps this history even when the process was killed natively, so it is the key clue
   * for "the app just exits" problems.
   */
  fun logPreviousExits(context: Context) {
    try {
      val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
      val exits = am.getHistoricalProcessExitReasons(context.packageName, 0, 5)
      if (exits.isEmpty()) {
        Log.i(TAG, "No previous process exit records found")
        return
      }
      exits.forEachIndexed { index, info ->
        Log.w(
          TAG,
          "Previous exit #$index: reason=${reasonName(info.reason)} status=${info.status} " +
            "importance=${info.importance} pss=${info.pss}kB rss=${info.rss}kB " +
            "timestamp=${info.timestamp} description=${info.description}",
        )
      }
    } catch (e: Exception) {
      Log.w(TAG, "Failed to read previous process exit reasons", e)
    }
  }

  private fun Long.toMb(): Long = this / (1024 * 1024)

  private fun reasonName(reason: Int): String =
    when (reason) {
      ApplicationExitInfo.REASON_ANR -> "ANR"
      ApplicationExitInfo.REASON_CRASH -> "CRASH (Java/Kotlin exception)"
      ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE (native crash / SIGSEGV)"
      ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
      ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
      ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
      ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
      ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY (killed by system / lmkd)"
      ApplicationExitInfo.REASON_OTHER -> "OTHER"
      ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
      ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED (killed by signal)"
      ApplicationExitInfo.REASON_UNKNOWN -> "UNKNOWN"
      ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
      ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
      else -> "OTHER($reason)"
    }
}
