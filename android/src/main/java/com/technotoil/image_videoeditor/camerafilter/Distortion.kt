package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

object Distortion {
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
  private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    color = Color.argb(0x55, 0, 0, 0)
  }

  fun drawBigHead(canvas: Canvas, frame: Bitmap, face: DetectedFace) {
    val b = face.boundingBox
    val cx = b.centerX()
    val cy = b.centerY()
    val scaleFactor = 1.55f

    canvas.save()
    val path = faceOvalPath(face)
    if (path != null) {
      val matrix = android.graphics.Matrix()
      matrix.postScale(scaleFactor, scaleFactor, cx, cy)
      path.transform(matrix)
      canvas.clipPath(path)
    } else {
      val radius = max(b.width(), b.height()) * 0.50f * scaleFactor
      val clip = Path()
      clip.addOval(RectF(cx - radius, cy - radius, cx + radius, cy + radius), Path.Direction.CW)
      canvas.clipPath(clip)
    }

    // Scale content by the same factor centered at (cx, cy) to align with the scaled clip boundary
    canvas.translate(cx, cy)
    canvas.scale(scaleFactor, scaleFactor)
    canvas.translate(-cx, -cy)
    canvas.drawBitmap(frame, 0f, 0f, paint)

    canvas.restore()
  }

  private fun drawCrowsFeet(canvas: Canvas, eye: android.graphics.PointF, eyeDist: Float, side: Int) {
    val len = eyeDist * 0.18f
    val baseX = eye.x + side * eyeDist * 0.28f
    val baseY = eye.y
    for (i in -1..1) {
      val angle = (i * 20 * Math.PI / 180).toFloat()
      val dx = cos(angle) * len * side
      val dy = sin(angle) * len + i * 2
      canvas.drawLine(baseX, baseY, baseX + dx, baseY + dy, linePaint)
    }
  }

  fun drawOldAge(canvas: Canvas, frame: Bitmap, face: DetectedFace) {
    val path = faceOvalPath(face) ?: return
    val b = face.boundingBox
    val le = leftEye(face)
    val re = rightEye(face)
    val eyeDist = if (le != null && re != null) {
      kotlin.math.hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    } else {
      b.width() * 0.4f
    }

    canvas.save()
    canvas.clipPath(path)

    paint.colorFilter = ColorMatrixColorFilter(ColorMatrices.AGED)
    canvas.drawBitmap(frame, 0f, 0f, paint)
    paint.colorFilter = null

    linePaint.strokeWidth = max(1f, b.width() * 0.01f)
    val foreheadY = b.top + b.height() * 0.18f
    for (i in 0 until 3) {
      val lineY = foreheadY + i * eyeDist * 0.12f
      canvas.drawLine(b.left + b.width() * 0.25f, lineY, b.left + b.width() * 0.75f, lineY, linePaint)
    }

    le?.let { drawCrowsFeet(canvas, it, eyeDist, -1) }
    re?.let { drawCrowsFeet(canvas, it, eyeDist, 1) }

    canvas.restore()

    val top = topOfHeadPoint(face)
    if (top != null) {
      val grayPaint = Paint(Paint.ANTI_ALIAS_FLAG)
      grayPaint.color = Color.argb(0x99, 0xB0, 0xB0, 0xB0)
      val rect = RectF(
        top.x - b.width() * 0.45f,
        top.y - b.height() * 0.15f,
        top.x - b.width() * 0.45f + b.width() * 0.9f,
        top.y - b.height() * 0.15f + b.height() * 0.35f,
      )
      canvas.drawOval(rect, grayPaint)
    }
  }
}
