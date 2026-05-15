package com.google.ai.edge.gallery.customtasks.invoiceextraction

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import java.io.File
import java.io.FileOutputStream

/**
 * Generates a professional A4 invoice PDF using Android's built-in PdfDocument API.
 * No external libraries required — 100% offline.
 */
class InvoicePdfGenerator(private val context: Context) {

  // A4 at 72 DPI (points): 595 × 842
  private val PAGE_WIDTH = 595
  private val PAGE_HEIGHT = 842
  private val MARGIN = 48f
  private val COL_QTY_W = 40f
  private val COL_PRICE_W = 80f
  private val COL_TOTAL_W = 80f

  fun generate(invoice: InvoiceData, profile: BusinessProfile, invoiceId: String): File {
    val outputFile = File(context.filesDir, "invoices/invoice_$invoiceId.pdf")
    outputFile.parentFile?.mkdirs()

    val pdfDocument = PdfDocument()
    val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, 1).create()
    val page = pdfDocument.startPage(pageInfo)
    draw(page.canvas, invoice, profile, invoiceId)
    pdfDocument.finishPage(page)

    FileOutputStream(outputFile).use { pdfDocument.writeTo(it) }
    pdfDocument.close()
    return outputFile
  }

  private fun draw(canvas: Canvas, invoice: InvoiceData, profile: BusinessProfile, invoiceId: String) {
    var y = MARGIN

    // --- Logo ---
    if (profile.logoPath.isNotEmpty()) {
      val logoFile = File(profile.logoPath)
      if (logoFile.exists()) {
        val bmp = BitmapFactory.decodeFile(logoFile.absolutePath)
        if (bmp != null) {
          val logoH = 60f
          val logoW = logoH * bmp.width / bmp.height.toFloat()
          val dest = RectF(MARGIN, y, MARGIN + logoW, y + logoH)
          canvas.drawBitmap(bmp, null, dest, null)
          bmp.recycle()
        }
      }
    }

    // --- Business header (right-aligned) ---
    val rightX = PAGE_WIDTH - MARGIN
    val headerPaint = Paint().apply { isAntiAlias = true }

    if (profile.businessName.isNotEmpty()) {
      headerPaint.apply {
        typeface = Typeface.DEFAULT_BOLD
        textSize = 18f
        color = Color.parseColor("#1A1A2E")
        textAlign = Paint.Align.RIGHT
      }
      canvas.drawText(profile.businessName, rightX, y + 14f, headerPaint)
      y += 18f

      if (profile.tagline.isNotEmpty()) {
        headerPaint.apply { typeface = Typeface.DEFAULT; textSize = 9f; color = Color.GRAY }
        canvas.drawText(profile.tagline, rightX, y + 10f, headerPaint)
        y += 12f
      }
      if (profile.address.isNotEmpty()) {
        headerPaint.apply { textSize = 9f; color = Color.DKGRAY }
        profile.address.lines().forEach { line ->
          canvas.drawText(line.trim(), rightX, y + 10f, headerPaint)
          y += 11f
        }
      }
      if (profile.phone.isNotEmpty()) {
        canvas.drawText(profile.phone, rightX, y + 10f, headerPaint)
        y += 11f
      }
      if (profile.email.isNotEmpty()) {
        canvas.drawText(profile.email, rightX, y + 10f, headerPaint)
        y += 11f
      }
    }

    y = maxOf(y, MARGIN + 70f) // ensure header has enough vertical space

    // --- Divider ---
    y += 12f
    drawHLine(canvas, y)
    y += 10f

    // --- "INVOICE" title + meta ---
    val titlePaint = Paint().apply {
      isAntiAlias = true
      typeface = Typeface.DEFAULT_BOLD
      textSize = 26f
      color = Color.parseColor("#1A1A2E")
      textAlign = Paint.Align.LEFT
    }
    canvas.drawText("INVOICE", MARGIN, y + 24f, titlePaint)

    val metaPaint = Paint().apply {
      isAntiAlias = true
      textSize = 9f
      color = Color.DKGRAY
      textAlign = Paint.Align.RIGHT
    }
    canvas.drawText("Invoice #: ${invoiceId.takeLast(8).uppercase()}", rightX, y + 10f, metaPaint)
    canvas.drawText("Date: ${invoice.date}", rightX, y + 22f, metaPaint)
    y += 36f

    // --- Bill To ---
    if (invoice.clientName.isNotEmpty()) {
      val billPaint = Paint().apply {
        isAntiAlias = true; textSize = 8f; color = Color.GRAY; textAlign = Paint.Align.LEFT
        typeface = Typeface.DEFAULT_BOLD
      }
      canvas.drawText("BILL TO", MARGIN, y + 10f, billPaint)
      y += 12f
      val clientPaint = Paint().apply {
        isAntiAlias = true; textSize = 11f; color = Color.parseColor("#1A1A2E")
        textAlign = Paint.Align.LEFT
      }
      canvas.drawText(invoice.clientName, MARGIN, y + 12f, clientPaint)
      y += 16f
    }

    y += 12f

    // --- Items table header ---
    val contentWidth = PAGE_WIDTH - 2 * MARGIN
    val colDescW = contentWidth - COL_QTY_W - COL_PRICE_W - COL_TOTAL_W

    drawTableHeader(canvas, y, colDescW)
    y += 20f
    drawHLine(canvas, y, width = 1f, color = Color.parseColor("#CCCCCC"))
    y += 6f

    // --- Item rows ---
    val rowPaint = Paint().apply {
      isAntiAlias = true; textSize = 9f; color = Color.parseColor("#333333")
    }
    val rowRightPaint = Paint().apply {
      isAntiAlias = true; textSize = 9f; color = Color.parseColor("#333333")
      textAlign = Paint.Align.RIGHT
    }

    for ((index, item) in invoice.items.withIndex()) {
      if (index % 2 == 0) {
        val bgPaint = Paint().apply { color = Color.parseColor("#F7F7F7") }
        canvas.drawRect(MARGIN, y - 2f, PAGE_WIDTH - MARGIN, y + 14f, bgPaint)
      }
      rowPaint.textAlign = Paint.Align.LEFT
      // Truncate description if too long
      val desc = item.description.take(45)
      canvas.drawText(desc, MARGIN + 4f, y + 10f, rowPaint)

      rowRightPaint.textAlign = Paint.Align.RIGHT
      canvas.drawText(
        fmtQty(item.qty),
        MARGIN + colDescW + COL_QTY_W, y + 10f, rowRightPaint,
      )
      canvas.drawText(
        fmtAmount(item.unitPrice),
        MARGIN + colDescW + COL_QTY_W + COL_PRICE_W, y + 10f, rowRightPaint,
      )
      canvas.drawText(
        fmtAmount(item.total),
        MARGIN + colDescW + COL_QTY_W + COL_PRICE_W + COL_TOTAL_W, y + 10f, rowRightPaint,
      )
      y += 16f
    }

    y += 8f
    drawHLine(canvas, y, width = 1f, color = Color.parseColor("#CCCCCC"))
    y += 10f

    // --- Totals ---
    drawTotalRow(canvas, y, "Subtotal", invoice.currency, invoice.subtotal)
    y += 16f
    if (invoice.tax > 0) {
      val taxLabel = if (invoice.taxPercent > 0) {
        val pctStr = if (invoice.taxPercent == invoice.taxPercent.toLong().toDouble())
          invoice.taxPercent.toLong().toString() else "%.2f".format(invoice.taxPercent)
        "Tax ($pctStr%)"
      } else "Tax"
      drawTotalRow(canvas, y, taxLabel, invoice.currency, invoice.tax)
      y += 16f
      drawHLine(canvas, y, width = 0.5f, color = Color.parseColor("#DDDDDD"))
      y += 8f
    }
    drawTotalRowBold(canvas, y, "TOTAL", invoice.currency, invoice.total)
    y += 24f

    // --- Notes ---
    if (invoice.notes.isNotEmpty()) {
      val notesPaint = Paint().apply {
        isAntiAlias = true; textSize = 8f; color = Color.GRAY; textAlign = Paint.Align.LEFT
      }
      canvas.drawText("Notes: ${invoice.notes}", MARGIN, y + 10f, notesPaint)
      y += 16f
    }

    // --- Payment instructions footer ---
    if (profile.paymentInstructions.isNotEmpty()) {
      y = PAGE_HEIGHT - MARGIN - (profile.paymentInstructions.lines().size * 11f) - 24f
      drawHLine(canvas, y, width = 0.5f, color = Color.parseColor("#CCCCCC"))
      y += 10f
      val footerLabel = Paint().apply {
        isAntiAlias = true; textSize = 8f; typeface = Typeface.DEFAULT_BOLD
        color = Color.DKGRAY; textAlign = Paint.Align.LEFT
      }
      canvas.drawText("PAYMENT DETAILS", MARGIN, y + 10f, footerLabel)
      y += 12f
      val footerText = Paint().apply {
        isAntiAlias = true; textSize = 8f; color = Color.GRAY; textAlign = Paint.Align.LEFT
      }
      profile.paymentInstructions.lines().forEach { line ->
        canvas.drawText(line.trim(), MARGIN, y + 10f, footerText)
        y += 11f
      }
    }

    // --- App watermark ---
    val waterPaint = Paint().apply {
      isAntiAlias = true; textSize = 7f; color = Color.LTGRAY
      textAlign = Paint.Align.CENTER
    }
    canvas.drawText(
      "Generated by Whisper to Invoice · Powered by Gemma 4 · 100% offline",
      PAGE_WIDTH / 2f, PAGE_HEIGHT - 10f, waterPaint,
    )
  }

  private fun drawHLine(canvas: Canvas, y: Float, width: Float = 1f, color: Int = Color.parseColor("#DDDDDD")) {
    val paint = Paint().apply { this.color = color; strokeWidth = width }
    canvas.drawLine(MARGIN, y, PAGE_WIDTH - MARGIN, y, paint)
  }

  private fun drawTableHeader(canvas: Canvas, y: Float, colDescW: Float) {
    val hPaint = Paint().apply {
      isAntiAlias = true; textSize = 8f; typeface = Typeface.DEFAULT_BOLD
      color = Color.parseColor("#666666")
    }
    val hRightPaint = Paint(hPaint).apply { textAlign = Paint.Align.RIGHT }
    hPaint.textAlign = Paint.Align.LEFT
    canvas.drawText("DESCRIPTION", MARGIN + 4f, y + 10f, hPaint)
    canvas.drawText("QTY", MARGIN + colDescW + COL_QTY_W, y + 10f, hRightPaint)
    canvas.drawText("UNIT PRICE", MARGIN + colDescW + COL_QTY_W + COL_PRICE_W, y + 10f, hRightPaint)
    canvas.drawText("TOTAL", MARGIN + colDescW + COL_QTY_W + COL_PRICE_W + COL_TOTAL_W, y + 10f, hRightPaint)
  }

  private fun drawTotalRow(canvas: Canvas, y: Float, label: String, currency: String, amount: Double) {
    val labelPaint = Paint().apply {
      isAntiAlias = true; textSize = 9f; color = Color.DKGRAY; textAlign = Paint.Align.LEFT
    }
    val amtPaint = Paint().apply {
      isAntiAlias = true; textSize = 9f; color = Color.parseColor("#333333"); textAlign = Paint.Align.RIGHT
    }
    val rightX = PAGE_WIDTH - MARGIN
    canvas.drawText(label, MARGIN, y + 10f, labelPaint)
    canvas.drawText("$currency ${fmtAmount(amount)}", rightX, y + 10f, amtPaint)
  }

  private fun drawTotalRowBold(canvas: Canvas, y: Float, label: String, currency: String, amount: Double) {
    val bold = Typeface.DEFAULT_BOLD
    val labelPaint = Paint().apply {
      isAntiAlias = true; textSize = 11f; color = Color.parseColor("#1A1A2E")
      typeface = bold; textAlign = Paint.Align.LEFT
    }
    val amtPaint = Paint().apply {
      isAntiAlias = true; textSize = 11f; color = Color.parseColor("#1A1A2E")
      typeface = bold; textAlign = Paint.Align.RIGHT
    }
    val rightX = PAGE_WIDTH - MARGIN
    canvas.drawText(label, MARGIN, y + 12f, labelPaint)
    canvas.drawText("$currency ${fmtAmount(amount)}", rightX, y + 12f, amtPaint)
  }

  private fun fmtQty(qty: Double): String =
    if (qty == qty.toLong().toDouble()) qty.toLong().toString() else "%.2f".format(qty)

  private fun fmtAmount(amount: Double): String = "%,.2f".format(amount)
}
