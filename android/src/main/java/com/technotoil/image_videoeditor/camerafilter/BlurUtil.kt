package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap

/**
 * Cheap real-time box-blur approximation via downscale->upscale. A GPU RenderEffect blur
 * (API 31+) only applies to an entire hardware-accelerated View layer, not an arbitrary
 * Bitmap-backed Canvas draw, so it can't be composited alongside the other Canvas-drawn
 * filters here without blurring the whole frame; the downscale trick works uniformly across
 * minSdk 26+ and is cheap enough for a small clipped face region at camera frame rate.
 */
object BlurUtil {
  fun blur(source: Bitmap, radius: Float): Bitmap {
    val scale = (1f / (radius.coerceAtLeast(1f) * 0.5f)).coerceIn(0.05f, 0.5f)
    val smallW = (source.width * scale).toInt().coerceAtLeast(1)
    val smallH = (source.height * scale).toInt().coerceAtLeast(1)
    val small = Bitmap.createScaledBitmap(source, smallW, smallH, true)
    val blurred = Bitmap.createScaledBitmap(small, source.width, source.height, true)
    if (small !== blurred) small.recycle()
    return blurred
  }
}
