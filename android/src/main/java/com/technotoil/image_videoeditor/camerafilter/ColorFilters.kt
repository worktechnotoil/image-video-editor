package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.BlendMode
import android.os.Build
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.Typeface
import kotlin.random.Random
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object ColorFilters {
  var isFrontCamera: Boolean = true
  private var grainBitmap: Bitmap? = null

  private fun noiseBitmap(): Bitmap {
    var bmp = grainBitmap
    if (bmp == null) {
      bmp = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888)
      grainBitmap = bmp
    }
    val pixels = IntArray(64 * 64)
    for (i in pixels.indices) {
      val v = Random.nextInt(256)
      pixels[i] = Color.argb(255, v, v, v)
    }
    bmp.setPixels(pixels, 0, 64, 0, 0, 64, 64)
    return bmp
  }

  private fun createFilterPaint(matrix: android.graphics.ColorMatrix): Paint {
    return Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
      colorFilter = ColorMatrixColorFilter(matrix)
    }
  }

  private fun drawVignette(canvas: Canvas, left: Float, top: Float, right: Float, bottom: Float) {
    val w = right - left
    val h = bottom - top
    val cx = left + w / 2f
    val cy = top + h / 2f
    val radius = maxOf(w, h) * 0.75f
    val gradient = RadialGradient(
      cx, cy, radius,
      intArrayOf(Color.TRANSPARENT, Color.TRANSPARENT, Color.argb(0xAA, 0, 0, 0)),
      floatArrayOf(0f, 0.55f, 1f),
      Shader.TileMode.CLAMP,
    )
    val vignettePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = gradient
    }
    canvas.drawRect(left, top, right, bottom, vignettePaint)
  }

  private fun drawFilmGrain(canvas: Canvas, left: Float, top: Float, right: Float, bottom: Float, alpha: Float = 0.12f) {
    val shader = android.graphics.BitmapShader(noiseBitmap(), Shader.TileMode.REPEAT, Shader.TileMode.REPEAT)
    val grainPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      this.shader = shader
      this.alpha = (alpha * 255).toInt()
      if (Build.VERSION.SDK_INT >= 29) {
        blendMode = BlendMode.OVERLAY
      } else {
        xfermode = PorterDuffXfermode(PorterDuff.Mode.SCREEN)
      }
    }
    canvas.drawRect(left, top, right, bottom, grainPaint)
  }

  fun applyVintage(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.VINTAGE))
    drawVignette(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat())
    drawFilmGrain(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat(), 0.12f)
  }

  fun applyBlackWhite(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.BLACK_WHITE))
  }

  fun applyVibrant(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.VIBRANT))
  }

  fun applyCoolTone(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.COOL_TONE))
  }

  fun applyWarmTone(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.WARM_TONE))
  }

  fun applyCyberpunk(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.CYBERPUNK))
  }

  fun applySunset(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.SUNSET))
  }

  fun applyIce(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.ICE))
  }

  fun applyRetroFilm(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.RETRO_FILM))
    drawVignette(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat())
  }

  fun applyBMWDark(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.BMW_DARK))
    drawVignette(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat())
  }

  fun applyAestheticPink(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.AESTHETIC_PINK))
    val cx = frame.width / 2f
    val cy = frame.height / 2f
    val r  = maxOf(frame.width, frame.height) * 0.80f
    val pinkVignettePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(cx, cy, r,
        intArrayOf(android.graphics.Color.TRANSPARENT,
                   android.graphics.Color.argb(0x55, 255, 180, 210)),
        floatArrayOf(0.45f, 1f),
        Shader.TileMode.CLAMP)
    }
    canvas.drawRect(0f, 0f, frame.width.toFloat(), frame.height.toFloat(), pinkVignettePaint)
  }

  fun applyNoir(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.NOIR))
    drawVignette(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat())
  }

  fun applyDarkMoon(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.DARK_MOON))
    drawVignette(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat())
    drawVignette(canvas, 0f, 0f, frame.width.toFloat(), frame.height.toFloat())
  }

  fun applyDayStamp(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.DAY_STAMP))

    val width = frame.width.toFloat()
    val height = frame.height.toFloat()

    val washPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        width * 0.55f, height * 0.28f, maxOf(width, height) * 0.95f,
        intArrayOf(
          Color.argb(0, 255, 246, 235),
          Color.argb(18, 255, 239, 224),
          Color.argb(72, 230, 210, 190),
        ),
        floatArrayOf(0f, 0.6f, 1f),
        Shader.TileMode.CLAMP,
      )
    }
    canvas.drawRect(0f, 0f, width, height, washPaint)

    val timePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(225, 255, 255, 255)
      textSize = height * 0.044f
      typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
      setShadowLayer(height * 0.004f, 0f, 0f, Color.argb(70, 0, 0, 0))
    }
    val dayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(240, 255, 248, 240)
      textSize = height * 0.080f
      typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
      letterSpacing = 0.02f
      setShadowLayer(height * 0.006f, 0f, 0f, Color.argb(90, 0, 0, 0))
    }

    val now = Date()
    val timeText = SimpleDateFormat("HH:mm", Locale.getDefault()).format(now)
    val dayText = SimpleDateFormat("EEEE", Locale.getDefault()).format(now).uppercase(Locale.getDefault())

    canvas.save()
    if (isFrontCamera) {
      canvas.translate(width, 0f)
      canvas.scale(-1f, 1f)
    }

    val left = width * 0.12f
    val baseline = height * 0.80f
    canvas.drawText(timeText, left, baseline - dayPaint.textSize * 0.82f, timePaint)
    canvas.drawText(dayText, left, baseline, dayPaint)

    canvas.restore()
  }

  fun applyBrightWhite(canvas: Canvas, frame: Bitmap) {
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(ColorMatrices.BRIGHT_WHITE))
  }

  fun applyVintageGrain(canvas: Canvas, frame: Bitmap) {
    val fw = frame.width.toFloat()
    val fh = frame.height.toFloat()

    val size = minOf(fw, fh)
    val left = (fw - size) / 2f
    val top = (fh - size) / 2f
    val right = left + size
    val bottom = top + size

    canvas.drawColor(Color.BLACK)

    val src = android.graphics.Rect(left.toInt(), top.toInt(), right.toInt(), bottom.toInt())
    val dst = android.graphics.RectF(left, top, right, bottom)

    canvas.drawBitmap(frame, src, dst, createFilterPaint(ColorMatrices.VINTAGE_GRAIN))

    drawVignette(canvas, left, top, right, bottom)
    drawFilmGrain(canvas, left, top, right, bottom, 0.15f)

    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(220, 240, 240, 240)
      style = Paint.Style.STROKE
      strokeWidth = size * 0.005f
    }
    canvas.drawRect(dst, borderPaint)
  }

  fun applyCreamySoftGlow(canvas: Canvas, frame: Bitmap) {
    val warmCreamMatrix = android.graphics.ColorMatrix(floatArrayOf(
      1.08f, 0.02f, 0f,    0f, 15f,
      0f,    1.03f, 0.01f, 0f, 8f,
      0f,    0f,    0.95f, 0f, -4f,
      0f,    0f,    0f,    1f, 0f,
    ))
    canvas.drawBitmap(frame, 0f, 0f, createFilterPaint(warmCreamMatrix))

    val w = frame.width.toFloat()
    val h = frame.height.toFloat()
    val cx = w / 2f
    val cy = h * 0.4f
    val r  = maxOf(w, h) * 0.85f
    val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(cx, cy, r,
        intArrayOf(
          Color.argb(0x1a, 255, 235, 215),
          Color.argb(0x0e, 255, 220, 200),
          Color.argb(0x28, 235, 205, 185)
        ),
        floatArrayOf(0f, 0.55f, 1f),
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawRect(0f, 0f, w, h, glowPaint)
  }
}
