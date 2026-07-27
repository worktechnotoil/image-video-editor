package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint

object BeautyFilters {
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

  fun drawSmoothSkin(canvas: Canvas, frame: Bitmap, face: DetectedFace) {
    val path = faceOvalPath(face) ?: return
    val rect = face.boundingBox
    val left = rect.left.toInt().coerceIn(0, frame.width - 1)
    val top = rect.top.toInt().coerceIn(0, frame.height - 1)
    val right = rect.right.toInt().coerceIn(left + 1, frame.width)
    val bottom = rect.bottom.toInt().coerceIn(top + 1, frame.height)
    val w = right - left
    val h = bottom - top
    if (w <= 0 || h <= 0) return

    val crop = Bitmap.createBitmap(frame, left, top, w, h)
    val blurredFace = BlurUtil.blur(crop, 12f)

    canvas.save()
    canvas.clipPath(path)
    paint.colorFilter = null
    paint.alpha = (0.55f * 255).toInt()
    canvas.drawBitmap(blurredFace, left.toFloat(), top.toFloat(), paint)
    paint.alpha = 255
    canvas.restore()

    blurredFace.recycle()
  }

  fun drawBrightenGlow(canvas: Canvas, frame: Bitmap, face: DetectedFace) {
    val path = faceOvalPath(face) ?: return
    canvas.save()
    canvas.clipPath(path)
    paint.colorFilter = ColorMatrixColorFilter(ColorMatrices.GLOW)
    paint.alpha = (0.5f * 255).toInt()
    canvas.drawBitmap(frame, 0f, 0f, paint)
    paint.colorFilter = null
    paint.alpha = 255
    canvas.restore()
  }

  fun drawLipstick(canvas: Canvas, face: DetectedFace, colorType: String) {
    val upperPath = upperLipPath(face)
    val lowerPath = lowerLipPath(face)
    if (upperPath == null && lowerPath == null) return

    val color = when (colorType) {
      "red" -> android.graphics.Color.argb(105, 220, 20, 60)
      "pink" -> android.graphics.Color.argb(95, 255, 60, 150)
      "coral" -> android.graphics.Color.argb(95, 255, 115, 65)
      "plum" -> android.graphics.Color.argb(110, 128, 0, 128)
      else -> android.graphics.Color.argb(105, 220, 20, 60)
    }

    val lipstickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      this.color = color
      this.style = Paint.Style.FILL
    }

    canvas.save()
    if (upperPath != null) {
      canvas.drawPath(upperPath, lipstickPaint)
    }
    if (lowerPath != null) {
      canvas.drawPath(lowerPath, lipstickPaint)
    }
    canvas.restore()
  }
}
