package com.technotoil.image_videoeditor.camerafilter

import android.graphics.ColorMatrix

/**
 * Same 4x5 row-major matrices as src/filters/colorMatrices.ts, but rescaled: Skia's offset
 * column is normalized (0-1 color space) while android.graphics.ColorMatrix expects offsets
 * in 0-255 space, so every 5th value (index 4, 9, 14, 19) is multiplied by 255.
 */
private fun matrix(skiaMatrix: FloatArray): ColorMatrix {
  val scaled = skiaMatrix.copyOf()
  for (row in 0 until 4) {
    val offsetIndex = row * 5 + 4
    scaled[offsetIndex] = scaled[offsetIndex] * 255f
  }
  return ColorMatrix(scaled)
}

object ColorMatrices {
  val VINTAGE = matrix(
    floatArrayOf(
      0.393f, 0.769f, 0.189f, 0f, 0f,
      0.349f, 0.686f, 0.168f, 0f, 0f,
      0.272f, 0.534f, 0.131f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val BLACK_WHITE = matrix(
    floatArrayOf(
      0.299f, 0.587f, 0.114f, 0f, 0f,
      0.299f, 0.587f, 0.114f, 0f, 0f,
      0.299f, 0.587f, 0.114f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val VIBRANT = matrix(
    floatArrayOf(
      1.3935f, -0.3575f, -0.036f, 0f, 0f,
      -0.1065f, 1.1425f, -0.036f, 0f, 0f,
      -0.1065f, -0.3575f, 1.464f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val COOL_TONE = matrix(
    floatArrayOf(
      0.9f, 0f, 0f, 0f, 0f,
      0f, 1.0f, 0f, 0f, 0f,
      0f, 0f, 1.15f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val WARM_TONE = matrix(
    floatArrayOf(
      1.15f, 0f, 0f, 0f, 0f,
      0f, 1.05f, 0f, 0f, 0f,
      0f, 0f, 0.85f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val AGED = matrix(
    floatArrayOf(
      0.55f, 0.55f, 0.55f, 0f, 0f,
      0.5f, 0.55f, 0.5f, 0f, 0f,
      0.5f, 0.5f, 0.55f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val GLOW = matrix(
    floatArrayOf(
      1.15f, 0f, 0f, 0f, 0.04f,
      0f, 1.12f, 0f, 0f, 0.03f,
      0f, 0f, 1.05f, 0f, 0f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val TEETH_WHITEN = matrix(
    floatArrayOf(
      0.755f, 0.205f, 0.040f, 0f, 0.05f,
      0.105f, 0.855f, 0.040f, 0f, 0.05f,
      0.105f, 0.205f, 0.690f, 0f, 0.05f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val CYBERPUNK = matrix(
    floatArrayOf(
      1.2f, 0f, 0.2f, 0f, 0.05f,
      0.1f, 0.8f, 0f, 0f, 0f,
      0.3f, 0f, 1.4f, 0f, 0.05f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val SUNSET = matrix(
    floatArrayOf(
      1.35f, 0f, 0f, 0f, 0.05f,
      0.1f, 1.0f, 0f, 0f, 0f,
      0f, 0f, 0.7f, 0f, -0.05f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val ICE = matrix(
    floatArrayOf(
      0.75f, 0.1f, 0f, 0f, 0f,
      0f, 1.1f, 0.1f, 0f, 0.02f,
      0f, 0.1f, 1.35f, 0f, 0.06f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val RETRO_FILM = matrix(
    floatArrayOf(
      0.95f, 0.05f, 0f, 0f, 0.05f,
      0.05f, 0.85f, 0f, 0f, 0.02f,
      0f, 0.05f, 0.70f, 0f, -0.02f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  val BMW_DARK = matrix(
    floatArrayOf(
      0.75f, 0f,    0.05f, 0f, -0.03f,
      0f,    0.85f, 0.05f, 0f, -0.01f,
      0.10f, 0.05f, 1.30f, 0f,  0.04f,
      0f,    0f,    0f,    1f,  0f,
    ),
  )

  val AESTHETIC_PINK = matrix(
    floatArrayOf(
      1.10f, 0.04f, 0f,    0f, 0.04f,
      0f,    1.04f, 0.02f, 0f, 0.03f,
      0f,    0.02f, 1.05f, 0f, 0.04f,
      0f,    0f,    0f,    1f, 0f,
    ),
  )

  val NOIR = matrix(
    floatArrayOf(
      0.5f, 0.5f, 0f, 0f, -0.08f,
      0.5f, 0.5f, 0f, 0f, -0.08f,
      0.5f, 0.5f, 0f, 0f, -0.08f,
      0f, 0f, 0f, 1f, 0f,
    ),
  )

  // Dark moon: grayscale + heavy shadow crush → very dark cinematic B&W
  val DARK_MOON = matrix(
    floatArrayOf(
      0.25f, 0.50f, 0.09f, 0f, -0.03f,
      0.25f, 0.50f, 0.09f, 0f, -0.03f,
      0.25f, 0.50f, 0.09f, 0f, -0.03f,
      0f,    0f,    0f,    1f,  0f,
    ),
  )

  val DAY_STAMP = matrix(
    floatArrayOf(
      1.04f, 0.04f, 0.00f, 0f, 0.04f,
      0.02f, 1.00f, 0.02f, 0f, 0.02f,
      0.00f, 0.03f, 0.96f, 0f, 0.01f,
      0f,    0f,    0f,    1f,  0f,
    ),
  )

  // Bright white: equal gain on all RGB channels + bright white offset exposure
  val BRIGHT_WHITE = matrix(
    floatArrayOf(
      1.22f, 0.00f, 0.00f, 0f, 0.06f,
      0.00f, 1.22f, 0.00f, 0f, 0.06f,
      0.00f, 0.00f, 1.22f, 0f, 0.06f,
      0f,    0f,    0f,    1f,  0f,
    ),
  )

  // Vintage Grain: low-contrast warm/sepia cream monochrome film look
  val VINTAGE_GRAIN = matrix(
    floatArrayOf(
      0.239f, 0.470f, 0.091f, 0f, 0.05f,
      0.239f, 0.470f, 0.091f, 0f, 0.04f,
      0.239f, 0.470f, 0.091f, 0f, 0.02f,
      0f,     0f,     0f,     1f, 0f,
    ),
  )
}
