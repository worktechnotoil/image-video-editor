package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import kotlin.math.abs

/**
 * CartoonFilter — illustrated / anime art-style filter.
 *
 * ── Approach ──────────────────────────────────────────────────────────────────
 *
 *  Most CPU-only approaches (posterize + blur) look bad because:
 *   • Posterization creates colour banding / blocky artefacts
 *   • CPU box-blur at low resolution creates pixelation when upscaled
 *
 *  This implementation uses a two-layer hybrid:
 *
 *  Layer 1 — GPU ColorMatrix (hardware-accelerated, 0 ms CPU cost):
 *    • Saturation × 2.2   → flat, vivid illustrated colour regions
 *    • Contrast  × 1.4    → pushes colours toward extremes (like toon shading)
 *    • Slight brightness  → clean bright illustrated look
 *    Combined these make skin, hair, background each snap to a distinct vivid hue.
 *
 *  Layer 2 — CPU edge detection at 1/4 scale (~57 k pixels only):
 *    • Sobel on grayscale of downscaled original
 *    • Edge pixels rendered as near-black alpha-blended overlay
 *    • At 1/4 scale, each edge pixel covers a 4×4 block → naturally thick lines
 *    • Drawn with FILTER_BITMAP_FLAG → smooth bilinear upscale avoids jaggies
 *
 *  Result: vivid flat colours + bold dark outlines = authentic cartoon look.
 *  CPU budget: ~2 ms / frame at 720p.
 */
object CartoonFilter {

    // ── Constants ──────────────────────────────────────────────────────────────
    /** Scale factor for edge detection. 4 → 1/4 linear (320×180 at 720p = 57 k px). */
    private const val EDGE_SCALE = 4

    /** Sobel magnitude threshold (0-255). */
    private const val EDGE_THRESHOLD = 18

    /** Max alpha of the black edge overlay (0-255). 220 = strong but not totally opaque. */
    private const val EDGE_ALPHA_MAX = 220

    // ── GPU colour-grade paint (built once) ────────────────────────────────────
    //   Layer 1: draw the full frame with this paint on the hardware-accelerated
    //   canvas — the GPU applies the ColorMatrix at no CPU cost.
    private val colorGradePaint: Paint by lazy {
        // Step A: Saturation matrix (Android built-in, perfectly calibrated)
        val satMatrix = ColorMatrix()
        satMatrix.setSaturation(2.2f)

        // Step B: Contrast + slight brightness
        //   R' = factor*R + offset
        //   offset = (1-factor)*0.5 → keeps mid-grey stable
        //   factor=1.4 → offset = -0.2  → in 0-255 space: -51
        val contrastMatrix = ColorMatrix(floatArrayOf(
            1.40f, 0f,    0f,    0f, -40f,
            0f,    1.40f, 0f,    0f, -40f,
            0f,    0f,    1.40f, 0f, -40f,
            0f,    0f,    0f,    1f,   0f,
        ))

        // Combine: first saturate, then contrast
        satMatrix.postConcat(contrastMatrix)

        Paint().apply {
            isAntiAlias = false
            colorFilter = ColorMatrixColorFilter(satMatrix)
        }
    }

    // ── CPU edge state (pre-allocated, zero GC per frame) ─────────────────────
    private var edgeBitmap:  Bitmap? = null
    private var downBitmap:  Bitmap? = null
    private var downCanvas:  Canvas? = null
    private var cachedSW = 0
    private var cachedSH = 0
    private var srcPx:   IntArray = IntArray(0)
    private var lumaArr: IntArray = IntArray(0)
    private var edgePx:  IntArray = IntArray(0)

    private val edgeDrawPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val downMatrix    = Matrix()
    private val upMatrix      = Matrix()

    // ─────────────────────────────────────────────────────────────────────────

    fun apply(canvas: Canvas, frame: Bitmap) {
        val fw = frame.width
        val fh = frame.height

        // ── Layer 1: GPU colour grade ─────────────────────────────────────────
        // Draws the entire frame with Saturation×2.2 + Contrast×1.4.
        // On a hardware-accelerated View canvas this is a single GPU draw call.
        canvas.drawBitmap(frame, 0f, 0f, colorGradePaint)

        // ── Layer 2: CPU edge detection at 1/EDGE_SCALE ───────────────────────
        val sw = fw / EDGE_SCALE
        val sh = fh / EDGE_SCALE

        if (sw != cachedSW || sh != cachedSH) {
            downBitmap?.recycle()
            edgeBitmap?.recycle()
            downBitmap = Bitmap.createBitmap(sw, sh, Bitmap.Config.ARGB_8888)
            edgeBitmap = Bitmap.createBitmap(sw, sh, Bitmap.Config.ARGB_8888)
            downCanvas = Canvas(downBitmap!!)
            cachedSW = sw; cachedSH = sh
            val n = sw * sh
            srcPx   = IntArray(n)
            lumaArr = IntArray(n)
            edgePx  = IntArray(n)
            upMatrix.setScale(fw.toFloat() / sw, fh.toFloat() / sh)
        }

        // Scale down the ORIGINAL frame (not the colour-graded one) for edges
        downMatrix.setScale(sw.toFloat() / fw, sh.toFloat() / fh)
        downCanvas!!.drawBitmap(frame, downMatrix, null)
        downBitmap!!.getPixels(srcPx, 0, sw, 0, 0, sw, sh)

        // BT.601 luma (integer fixed-point, bit-shifts only)
        for (i in srcPx.indices) {
            val p = srcPx[i]
            lumaArr[i] = (77  * (p ushr 16 and 0xFF) +
                          150 * (p ushr  8 and 0xFF) +
                          29  * (p         and 0xFF)) ushr 8
        }

        // Sobel edge detection — result stored as alpha-only black pixels
        for (i in edgePx.indices) edgePx[i] = Color.TRANSPARENT

        for (y in 1 until sh - 1) {
            val row = y * sw
            for (x in 1 until sw - 1) {
                val gx = (-lumaArr[row - sw + x - 1] - 2 * lumaArr[row + x - 1] - lumaArr[row + sw + x - 1]
                          +lumaArr[row - sw + x + 1] + 2 * lumaArr[row + x + 1] + lumaArr[row + sw + x + 1])
                val gy = (-lumaArr[row - sw + x - 1] - 2 * lumaArr[row - sw + x] - lumaArr[row - sw + x + 1]
                          +lumaArr[row + sw + x - 1] + 2 * lumaArr[row + sw + x] + lumaArr[row + sw + x + 1])
                val mag = (abs(gx) + abs(gy)) ushr 1   // normalise to ~0-255

                if (mag > EDGE_THRESHOLD) {
                    val alpha = ((mag - EDGE_THRESHOLD).toLong() * EDGE_ALPHA_MAX /
                        (255 - EDGE_THRESHOLD)).toInt().coerceIn(0, EDGE_ALPHA_MAX)
                    edgePx[row + x] = Color.argb(alpha, 0, 0, 0)
                }
            }
        }

        // Write edge pixels and overlay on canvas (bilinear upscale = smooth lines)
        edgeBitmap!!.setPixels(edgePx, 0, sw, 0, 0, sw, sh)
        canvas.drawBitmap(edgeBitmap!!, upMatrix, edgeDrawPaint)
    }
}
