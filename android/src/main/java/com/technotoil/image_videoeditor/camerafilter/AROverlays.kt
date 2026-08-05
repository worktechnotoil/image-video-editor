package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.RadialGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import com.technotoil.image_videoeditor.camerafilter.bottomOfFacePoint
import com.technotoil.image_videoeditor.camerafilter.eyeDistance
import com.technotoil.image_videoeditor.camerafilter.faceOvalPath
import com.technotoil.image_videoeditor.camerafilter.leftCheek
import com.technotoil.image_videoeditor.camerafilter.leftEye
import com.technotoil.image_videoeditor.camerafilter.leftEar
import com.technotoil.image_videoeditor.camerafilter.mouthPath
import com.technotoil.image_videoeditor.camerafilter.noseBase
import com.technotoil.image_videoeditor.camerafilter.rightCheek
import com.technotoil.image_videoeditor.camerafilter.rightEye
import com.technotoil.image_videoeditor.camerafilter.rightEar
import com.technotoil.image_videoeditor.camerafilter.topLeftFacePoint
import com.technotoil.image_videoeditor.camerafilter.topRightFacePoint
import com.technotoil.image_videoeditor.camerafilter.topOfHeadPoint
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random

object AROverlays {
  var isFrontCamera: Boolean = true

  enum class DogStyleType {
    BROWN, DALMATIAN
  }
  enum class CatStyleType {
    GRAY, PINK
  }
  enum class FlowerStyleType {
    PINK, GOLD
  }
  enum class GlassStyleType {
    CLASSIC, SUN, RETRO, HEART, SPORT
  }
  enum class HatStyleType {
    WIZARD, COWBOY, SANTA
  }

  private inline fun withHeadRotation(canvas: Canvas, anchor: PointF, rollAngle: Float, draw: () -> Unit) {
    canvas.save()
    canvas.translate(anchor.x, anchor.y)
    canvas.rotate(-rollAngle)
    canvas.translate(-anchor.x, -anchor.y)
    draw()
    canvas.restore()
  }

  private fun getLocalPoint(screenPt: PointF, anchor: PointF, rollAngle: Float): PointF {
    val rad = Math.toRadians(rollAngle.toDouble()).toFloat()
    val cosVal = cos(rad.toDouble()).toFloat()
    val sinVal = sin(rad.toDouble()).toFloat()
    val dx = screenPt.x - anchor.x
    val dy = screenPt.y - anchor.y
    val rx = dx * cosVal - dy * sinVal
    val ry = dx * sinVal + dy * cosVal
    return PointF(anchor.x + rx, anchor.y + ry)
  }

  fun drawDogEars(canvas: Canvas, face: DetectedFace, dogStyle: DogStyleType = DogStyleType.DALMATIAN) {
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val nose = noseBase(face) ?: return
    val rollAngle = face.rollAngle

    val eyeDistance = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val faceCenterX = (le.x + re.x) / 2f
    val faceCenterY = (le.y + re.y) / 2f
    val earLocalY = -eyeDistance * 1.45f
    val noseLocalY = nose.y - faceCenterY

    canvas.save()
    canvas.translate(faceCenterX, faceCenterY)
    canvas.rotate(-rollAngle)

    val earPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    val innerEarPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#ffccd5") // cute light pink
    }
    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#DDDDDD")
      style = Paint.Style.STROKE
      strokeWidth = eyeDistance * 0.015f
    }

    if (dogStyle == DogStyleType.DALMATIAN) {
      earPaint.shader = LinearGradient(
        0f, earLocalY,
        0f, earLocalY + eyeDistance * 1.5f,
        Color.WHITE, Color.parseColor("#F5F5F5"),
        Shader.TileMode.CLAMP
      )
    } else {
      earPaint.shader = LinearGradient(
        0f, earLocalY,
        0f, earLocalY + eyeDistance * 1.5f,
        Color.parseColor("#6e472f"), Color.parseColor("#422b1d"),
        Shader.TileMode.CLAMP
      )
      innerEarPaint.color = Color.parseColor("#d99a7c")
      borderPaint.color = Color.parseColor("#5b3a24")
    }

    val leftEarX = eyeDistance * 0.60f
    val rightEarX = -eyeDistance * 0.60f

    // ── Left Floppy Ear Path ──
    val leftEarPath = Path().apply {
      // Start at top-inner corner
      moveTo(leftEarX, earLocalY + eyeDistance * 0.1f)
      // Curve to top-outer corner (make it broader: extend x more)
      cubicTo(
        leftEarX + eyeDistance * 0.25f, earLocalY - eyeDistance * 0.18f,
        leftEarX + eyeDistance * 0.55f, earLocalY - eyeDistance * 0.08f,
        leftEarX + eyeDistance * 0.70f, earLocalY + eyeDistance * 0.15f
      )
      // Curve down to outer tip
      cubicTo(
        leftEarX + eyeDistance * 0.88f, earLocalY + eyeDistance * 0.45f,
        leftEarX + eyeDistance * 0.82f, earLocalY + eyeDistance * 0.75f,
        leftEarX + eyeDistance * 0.50f, earLocalY + eyeDistance * 0.88f  // Ear Tip
      )
      // Curve back up along the head side
      cubicTo(
        leftEarX + eyeDistance * 0.25f, earLocalY + eyeDistance * 0.80f,
        leftEarX + eyeDistance * 0.12f, earLocalY + eyeDistance * 0.45f,
        leftEarX, earLocalY + eyeDistance * 0.25f
      )
      close()
    }

    // Draw Left Ear
    canvas.save()
    canvas.clipPath(leftEarPath)
    canvas.drawPath(leftEarPath, earPaint)
    
    // Draw Inner Pink Flap
    val leftInnerPath = Path().apply {
      moveTo(leftEarX + eyeDistance * 0.12f, earLocalY + eyeDistance * 0.22f)
      cubicTo(
        leftEarX + eyeDistance * 0.35f, earLocalY + eyeDistance * 0.28f,
        leftEarX + eyeDistance * 0.48f, earLocalY + eyeDistance * 0.52f,
        leftEarX + eyeDistance * 0.40f, earLocalY + eyeDistance * 0.70f
      )
      cubicTo(
        leftEarX + eyeDistance * 0.28f, earLocalY + eyeDistance * 0.70f,
        leftEarX + eyeDistance * 0.15f, earLocalY + eyeDistance * 0.52f,
        leftEarX + eyeDistance * 0.06f, earLocalY + eyeDistance * 0.28f
      )
      close()
    }
    canvas.drawPath(leftInnerPath, innerEarPaint)

    // Draw Dalmatian spots on left ear
    if (dogStyle == DogStyleType.DALMATIAN) {
      val spotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
      canvas.drawCircle(leftEarX + eyeDistance * 0.22f, earLocalY + eyeDistance * 0.15f, eyeDistance * 0.10f, spotPaint)
      canvas.drawCircle(leftEarX + eyeDistance * 0.45f, earLocalY + eyeDistance * 0.32f, eyeDistance * 0.12f, spotPaint)
      canvas.drawCircle(leftEarX + eyeDistance * 0.58f, earLocalY + eyeDistance * 0.50f, eyeDistance * 0.11f, spotPaint)
      canvas.drawCircle(leftEarX + eyeDistance * 0.35f, earLocalY + eyeDistance * 0.72f, eyeDistance * 0.09f, spotPaint)
      canvas.drawCircle(leftEarX + eyeDistance * 0.12f, earLocalY + eyeDistance * 0.48f, eyeDistance * 0.08f, spotPaint)
    }
    canvas.restore()
    canvas.drawPath(leftEarPath, borderPaint)

    // ── Right Floppy Ear Path ──
    val rightEarPath = Path().apply {
      // Start at top-inner corner
      moveTo(rightEarX, earLocalY + eyeDistance * 0.1f)
      // Curve to top-outer corner (make it broader: extend x more in negative direction)
      cubicTo(
        rightEarX - eyeDistance * 0.25f, earLocalY - eyeDistance * 0.18f,
        rightEarX - eyeDistance * 0.55f, earLocalY - eyeDistance * 0.08f,
        rightEarX - eyeDistance * 0.70f, earLocalY + eyeDistance * 0.15f
      )
      // Curve down to outer tip
      cubicTo(
        rightEarX - eyeDistance * 0.88f, earLocalY + eyeDistance * 0.45f,
        rightEarX - eyeDistance * 0.82f, earLocalY + eyeDistance * 0.75f,
        rightEarX - eyeDistance * 0.50f, earLocalY + eyeDistance * 0.88f  // Ear Tip
      )
      // Curve back up along the head side
      cubicTo(
        rightEarX - eyeDistance * 0.25f, earLocalY + eyeDistance * 0.80f,
        rightEarX - eyeDistance * 0.12f, earLocalY + eyeDistance * 0.45f,
        rightEarX, earLocalY + eyeDistance * 0.25f
      )
      close()
    }

    // Draw Right Ear
    canvas.save()
    canvas.clipPath(rightEarPath)
    canvas.drawPath(rightEarPath, earPaint)
    
    // Draw Inner Pink Flap
    val rightInnerPath = Path().apply {
      moveTo(rightEarX - eyeDistance * 0.12f, earLocalY + eyeDistance * 0.22f)
      cubicTo(
        rightEarX - eyeDistance * 0.35f, earLocalY + eyeDistance * 0.28f,
        rightEarX - eyeDistance * 0.48f, earLocalY + eyeDistance * 0.52f,
        rightEarX - eyeDistance * 0.40f, earLocalY + eyeDistance * 0.70f
      )
      cubicTo(
        rightEarX - eyeDistance * 0.28f, earLocalY + eyeDistance * 0.70f,
        rightEarX - eyeDistance * 0.15f, earLocalY + eyeDistance * 0.52f,
        rightEarX - eyeDistance * 0.06f, earLocalY + eyeDistance * 0.28f
      )
      close()
    }
    canvas.drawPath(rightInnerPath, innerEarPaint)

    // Draw Dalmatian spots on right ear
    if (dogStyle == DogStyleType.DALMATIAN) {
      val spotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
      canvas.drawCircle(rightEarX - eyeDistance * 0.22f, earLocalY + eyeDistance * 0.15f, eyeDistance * 0.10f, spotPaint)
      canvas.drawCircle(rightEarX - eyeDistance * 0.45f, earLocalY + eyeDistance * 0.32f, eyeDistance * 0.12f, spotPaint)
      canvas.drawCircle(rightEarX - eyeDistance * 0.58f, earLocalY + eyeDistance * 0.50f, eyeDistance * 0.11f, spotPaint)
      canvas.drawCircle(rightEarX - eyeDistance * 0.35f, earLocalY + eyeDistance * 0.72f, eyeDistance * 0.09f, spotPaint)
      canvas.drawCircle(rightEarX - eyeDistance * 0.12f, earLocalY + eyeDistance * 0.48f, eyeDistance * 0.08f, spotPaint)
    }
    canvas.restore()
    canvas.drawPath(rightEarPath, borderPaint)

    // ── Muzzle (Cheeks/Jowls) ──
    val muzzlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = if (dogStyle == DogStyleType.DALMATIAN) Color.WHITE else Color.parseColor("#F5F5F0")
    }
    val muzzleBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#E0E0E0")
      style = Paint.Style.STROKE
      strokeWidth = eyeDistance * 0.01f
    }

    val muzzlePath = Path().apply {
      addCircle(-eyeDistance * 0.15f, noseLocalY + eyeDistance * 0.06f, eyeDistance * 0.20f, Path.Direction.CW)
      addCircle(eyeDistance * 0.15f, noseLocalY + eyeDistance * 0.06f, eyeDistance * 0.20f, Path.Direction.CW)
    }

    // Draw Muzzle Background
    canvas.drawPath(muzzlePath, muzzlePaint)
    canvas.drawPath(muzzlePath, muzzleBorderPaint)

    // Clip and Draw Spots inside Muzzle
    canvas.save()
    canvas.clipPath(muzzlePath)
    val spotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
    if (dogStyle == DogStyleType.DALMATIAN) {
      canvas.drawCircle(-eyeDistance * 0.22f, noseLocalY + eyeDistance * 0.04f, eyeDistance * 0.04f, spotPaint)
      canvas.drawCircle(-eyeDistance * 0.10f, noseLocalY + eyeDistance * 0.18f, eyeDistance * 0.03f, spotPaint)
      canvas.drawCircle(eyeDistance * 0.20f, noseLocalY + eyeDistance * 0.08f, eyeDistance * 0.05f, spotPaint)
      canvas.drawCircle(eyeDistance * 0.12f, noseLocalY + eyeDistance * 0.16f, eyeDistance * 0.03f, spotPaint)
    }
    canvas.restore()

    // Draw Whisker Dots
    val whiskerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#555555") }
    val dotR = eyeDistance * 0.012f
    canvas.drawCircle(-eyeDistance * 0.10f, noseLocalY + eyeDistance * 0.05f, dotR, whiskerPaint)
    canvas.drawCircle(-eyeDistance * 0.16f, noseLocalY + eyeDistance * 0.07f, dotR, whiskerPaint)
    canvas.drawCircle(-eyeDistance * 0.12f, noseLocalY + eyeDistance * 0.11f, dotR, whiskerPaint)
    
    canvas.drawCircle(eyeDistance * 0.10f, noseLocalY + eyeDistance * 0.05f, dotR, whiskerPaint)
    canvas.drawCircle(eyeDistance * 0.16f, noseLocalY + eyeDistance * 0.07f, dotR, whiskerPaint)
    canvas.drawCircle(eyeDistance * 0.12f, noseLocalY + eyeDistance * 0.11f, dotR, whiskerPaint)

    // ── Dog Nose ──
    val nosePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
    val nosePath = Path().apply {
      val ncx = 0f
      val ncy = noseLocalY - eyeDistance * 0.04f
      val nw = eyeDistance * 0.14f
      val nh = eyeDistance * 0.09f
      
      moveTo(ncx - nw, ncy)
      cubicTo(
        ncx - nw, ncy - nh,
        ncx + nw, ncy - nh,
        ncx + nw, ncy
      )
      cubicTo(
        ncx + nw, ncy + nh * 0.8f,
        ncx, ncy + nh * 1.2f,
        ncx, ncy + nh * 1.2f
      )
      cubicTo(
        ncx, ncy + nh * 1.2f,
        ncx - nw, ncy + nh * 0.8f,
        ncx - nw, ncy
      )
      close()
    }
    canvas.drawPath(nosePath, nosePaint)

    // Nose Shine Highlight
    val shinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(0xCC, 0xFF, 0xFF, 0xFF) }
    canvas.drawCircle(-eyeDistance * 0.05f, noseLocalY - eyeDistance * 0.08f, eyeDistance * 0.025f, shinePaint)

    canvas.restore()
  }

  fun drawCatEars(canvas: Canvas, face: DetectedFace, catStyle: CatStyleType = CatStyleType.GRAY) {
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val nose = noseBase(face) ?: return
    val rollAngle = face.rollAngle

    val eyeDistance = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val faceW = face.boundingBox.width()
    val faceH = face.boundingBox.height()

    // Symmetrical positioning around center of the face
    val centerX = (le.x + re.x) / 2f
    val centerY = (le.y + re.y) / 2f

    // Save and transform canvas to face coordinates
    canvas.save()
    canvas.translate(centerX, centerY)
    canvas.rotate(-rollAngle)

    val time = SystemClock.uptimeMillis().toFloat()

    // 1. Draw ears
    val earWidth = eyeDistance * 0.65f
    val earHeight = eyeDistance * 0.72f
    val leftEarX = -eyeDistance * 0.60f
    val rightEarX = eyeDistance * 0.60f
    val earLocalY = -eyeDistance * 1.45f

    fun drawSingleCatEar(ex: Float, isLeft: Boolean) {
      val outer = Path()
      val tilt = if (isLeft) -8f else 8f
      
      canvas.save()
      canvas.translate(ex, earLocalY)
      canvas.rotate(tilt)

      // Outer ear base path
      outer.moveTo(-earWidth * 0.5f, earHeight * 0.35f)
      outer.cubicTo(-earWidth * 0.45f, -earHeight * 0.45f, -earWidth * 0.05f, -earHeight * 0.75f, 0f, -earHeight * 0.75f)
      outer.cubicTo(earWidth * 0.05f, -earHeight * 0.75f, earWidth * 0.45f, -earHeight * 0.45f, earWidth * 0.5f, earHeight * 0.35f)
      outer.close()

      val outerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = if (catStyle == CatStyleType.PINK) Color.parseColor("#ffa6c9") else Color.parseColor("#5e5e5e")
      }
      canvas.drawPath(outer, outerPaint)

      // Inner ear pink center
      val inner = Path()
      inner.moveTo(-earWidth * 0.32f, earHeight * 0.28f)
      inner.cubicTo(-earWidth * 0.28f, -earHeight * 0.32f, -earWidth * 0.03f, -earHeight * 0.52f, 0f, -earHeight * 0.52f)
      inner.cubicTo(earWidth * 0.03f, -earHeight * 0.52f, earWidth * 0.28f, -earHeight * 0.32f, earWidth * 0.32f, earHeight * 0.28f)
      inner.close()

      val innerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = if (catStyle == CatStyleType.PINK) Color.parseColor("#ff5c8a") else Color.parseColor("#f096a8")
      }
      canvas.drawPath(inner, innerPaint)

      // Sparkly gemstones inside the ear (as seen in the reference image)
      val sparkleColors = intArrayOf(
        Color.parseColor("#ffc6ff"), // Lavender
        Color.parseColor("#ffadad"), // Pastel red
        Color.parseColor("#fdffb6"), // Yellow
        Color.parseColor("#ffffff"), // White
        Color.parseColor("#ff70a6")  // Pink
      )
      
      val random = java.util.Random(12345L)
      for (i in 0 until 18) {
        val rx = (random.nextFloat() - 0.5f) * earWidth * 0.4f
        val ry = (random.nextFloat() - 0.5f) * earHeight * 0.4f - earHeight * 0.1f
        val rSize = eyeDistance * (0.015f + random.nextFloat() * 0.02f)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
          color = sparkleColors[random.nextInt(sparkleColors.size)]
          if (random.nextBoolean()) {
            setShadowLayer(rSize * 0.6f, 0f, 0f, color)
          }
        }
        canvas.drawCircle(rx, ry, rSize, p)
      }

      canvas.restore()
    }

    drawSingleCatEar(leftEarX, true)
    drawSingleCatEar(rightEarX, false)

    // 2. Draw Cat Nose
    val noseLocalY = nose.y - centerY
    val nw = eyeDistance * 0.12f
    val nh = eyeDistance * 0.07f

    val nosePath = Path()
    nosePath.moveTo(0f, noseLocalY - nh * 0.2f)
    nosePath.cubicTo(-nw * 0.5f, noseLocalY - nh * 0.7f, -nw, noseLocalY - nh * 0.1f, -nw * 0.2f, noseLocalY + nh * 0.4f)
    nosePath.lineTo(0f, noseLocalY + nh * 0.7f)
    nosePath.lineTo(nw * 0.2f, noseLocalY + nh * 0.4f)
    nosePath.cubicTo(nw, noseLocalY - nh * 0.1f, nw * 0.5f, noseLocalY - nh * 0.7f, 0f, noseLocalY - nh * 0.2f)
    nosePath.close()

    val nosePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#ff85a2")
    }
    canvas.drawPath(nosePath, nosePaint)

    // Nose Highlight shine
    val shinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(220, 255, 255, 255)
    }
    canvas.drawCircle(-nw * 0.22f, noseLocalY - nh * 0.15f, nw * 0.15f, shinePaint)

    // 3. Draw Cat Whiskers (3 on each cheek)
    val whiskerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(200, 255, 255, 255)
      style = Paint.Style.STROKE
      strokeWidth = eyeDistance * 0.015f
      strokeCap = Paint.Cap.ROUND
    }

    val leftStart = -eyeDistance * 0.16f
    canvas.drawLine(leftStart, noseLocalY + eyeDistance * 0.03f, -eyeDistance * 0.65f, noseLocalY - eyeDistance * 0.05f, whiskerPaint)
    canvas.drawLine(leftStart, noseLocalY + eyeDistance * 0.06f, -eyeDistance * 0.68f, noseLocalY + eyeDistance * 0.06f, whiskerPaint)
    canvas.drawLine(leftStart, noseLocalY + eyeDistance * 0.09f, -eyeDistance * 0.65f, noseLocalY + eyeDistance * 0.17f, whiskerPaint)

    val rightStart = eyeDistance * 0.16f
    canvas.drawLine(rightStart, noseLocalY + eyeDistance * 0.03f, eyeDistance * 0.65f, noseLocalY - eyeDistance * 0.05f, whiskerPaint)
    canvas.drawLine(rightStart, noseLocalY + eyeDistance * 0.06f, eyeDistance * 0.68f, noseLocalY + eyeDistance * 0.06f, whiskerPaint)
    canvas.drawLine(rightStart, noseLocalY + eyeDistance * 0.09f, eyeDistance * 0.65f, noseLocalY + eyeDistance * 0.17f, whiskerPaint)

    // 4. Draw Floating Pink Hearts
    val heartLocations = listOf(
      Triple(-0.68f, -0.42f, 0.09f),
      Triple(-0.35f, -0.65f, 0.07f),
      Triple( 0.35f, -0.65f, 0.07f),
      Triple( 0.68f, -0.42f, 0.09f),
      Triple(-0.85f,  0.05f, 0.08f),
      Triple( 0.85f,  0.05f, 0.08f),
      Triple(-0.55f,  0.42f, 0.06f),
      Triple( 0.55f,  0.42f, 0.06f)
    )

    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#ffa6c9")
      style = Paint.Style.FILL
    }
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = eyeDistance * 0.012f
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
    }

    heartLocations.forEachIndexed { index, (rx, ry, sizeMult) ->
      val bobY = kotlin.math.sin(time * 0.0028f + index * 1.2f) * faceH * 0.03f
      val bobScale = 1.0f + kotlin.math.sin(time * 0.0035f + index) * 0.12f
      val hCx = rx * faceW
      val hCy = ry * faceH + bobY
      val w = faceW * sizeMult * bobScale
      val h = w * 1.05f

      canvas.save()
      canvas.translate(hCx, hCy)
      canvas.rotate(kotlin.math.sin(time * 0.002f + index) * 8f)

      val heartPath = Path()
      heartPath.moveTo(0f, h * 0.35f)
      heartPath.cubicTo(-w * 0.45f, -h * 0.1f, -w * 0.4f, -h * 0.45f, -w * 0.15f, -h * 0.45f)
      heartPath.cubicTo(0f, -h * 0.45f, 0f, -h * 0.1f, 0f, -h * 0.1f)
      heartPath.cubicTo(0f, -h * 0.1f, 0f, -h * 0.45f, w * 0.15f, -h * 0.45f)
      heartPath.cubicTo(w * 0.4f, -h * 0.45f, w * 0.45f, -h * 0.1f, 0f, h * 0.35f)
      heartPath.close()

      canvas.drawPath(heartPath, fillPaint)
      canvas.drawPath(heartPath, strokePaint)
      canvas.restore()
    }

    canvas.restore()
  }

  private val flowerColors = listOf("#ff6f91", "#ffc75f", "#f9f871", "#ff9671", "#d65db1")
  private val goldColors = listOf("#ffd700", "#ffc300", "#ffa000", "#ffb700", "#ffe066")

  private fun drawFlower(canvas: Canvas, cx: Float, cy: Float, size: Float, hue: String, centerColor: Int) {
    val petalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor(hue) }
    for (i in 0 until 5) {
      val angle = (i * 2 * Math.PI / 5).toFloat()
      val px = cx + cos(angle) * size * 0.55f
      val py = cy + sin(angle) * size * 0.55f
      canvas.drawCircle(px, py, size * 0.4f, petalPaint)
    }
    val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = centerColor }
    canvas.drawCircle(cx, cy, size * 0.32f, centerPaint)
  }

  fun drawFlowerCrown(canvas: Canvas, face: DetectedFace, flowerStyle: FlowerStyleType = FlowerStyleType.PINK) {
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val rollAngle = face.rollAngle

    val eyeDistance = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val centerY = (le.y + re.y) / 2
    val centerX = (le.x + re.x) / 2
    // Move the flower crown up to rest on the hair/top of head rather than the forehead/eyebrows
    // MLKit face contour top is at eyebrow level, so we must anchor from the eyes instead.
    val bandY = centerY - eyeDistance * 0.95f
    val anchor = PointF(centerX, bandY)
    val flowerSize = eyeDistance * 0.32f

    withHeadRotation(canvas, anchor, rollAngle) {
      val colors = if (flowerStyle == FlowerStyleType.GOLD) goldColors else flowerColors
      val centerColor = if (flowerStyle == FlowerStyleType.GOLD) Color.parseColor("#ff5722") else Color.parseColor("#f5c542")
      
      for (i in -2..2) {
        val fx = centerX + i * flowerSize * 1.3f
        val fy = bandY + kotlin.math.abs(i) * flowerSize * 0.25f
        drawFlower(canvas, fx, fy, flowerSize, colors[(i + 2) % colors.size], centerColor)
      }
    }
  }

  fun drawEvilHorns(canvas: Canvas, face: DetectedFace) {
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val rollAngle = face.rollAngle

    val eyeMidX = (le.x + re.x) / 2f
    val eyeMidY = (le.y + re.y) / 2f
    val eyeDist = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val anchor  = PointF(eyeMidX, eyeMidY)

    // ── Neon stroke thickness layers ─────────────────────────────────────────
    val coreW = eyeDist * 0.038f   // bright white core
    val midW  = eyeDist * 0.095f   // mid red halo
    val glowW = eyeDist * 0.220f   // soft outer red bloom

    // ── Horn geometry ─────────────────────────────────────────────────────────
    val hornH   = eyeDist * 1.08f   // vertical height of horn
    val hornArc = eyeDist * 0.72f   // how far outward the outer arc sweeps

    withHeadRotation(canvas, anchor, rollAngle) {

      // sweep: -1f = left horn (sweeps outward-left), +1f = right horn (sweeps outward-right)
      fun drawNeonHorn(cx: Float, cy: Float, sweep: Float) {

        // Bottom endpoint — slightly outward from center (the curl terminus)
        val botX = cx + sweep * eyeDist * 0.04f
        val botY = cy + eyeDist * 0.06f

        // Top endpoint — tip, very slightly inward lean
        val tipX = cx - sweep * eyeDist * 0.04f
        val tipY = cy - hornH

        // ── OUTER ARC — sweeps wide outward, the large visible bow ───────────
        val outerPath = Path()
        outerPath.moveTo(botX, botY)
        outerPath.cubicTo(
          botX + sweep * hornArc * 0.92f,  botY - hornH * 0.24f,
          tipX + sweep * hornArc * 0.46f,  tipY + hornH * 0.52f,
          tipX, tipY,
        )

        // ── INNER ARC — tighter parallel arc, ~eyeDist*0.15 inside the outer ─
        val innerPath = Path()
        val inset = eyeDist * 0.15f
        innerPath.moveTo(botX - sweep * inset * 0.30f, botY - eyeDist * 0.09f)
        innerPath.cubicTo(
          botX + sweep * (hornArc * 0.92f - inset),          botY - hornH * 0.22f,
          tipX + sweep * (hornArc * 0.46f - inset * 0.65f),  tipY + hornH * 0.50f,
          tipX + sweep * inset * 0.04f,                       tipY + eyeDist * 0.07f,
        )

        // ── Radial red bloom behind the arc area ─────────────────────────────
        val bgX = cx + sweep * hornArc * 0.38f
        val bgY = cy - hornH * 0.44f
        canvas.drawCircle(bgX, bgY, eyeDist * 0.58f,
          Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
              bgX, bgY, eyeDist * 0.58f,
              intArrayOf(Color.argb(75, 255, 0, 0), Color.TRANSPARENT),
              floatArrayOf(0f, 1f), Shader.TileMode.CLAMP,
            )
          }
        )

        // ── Layered neon draw on a path ───────────────────────────────────────
        fun neonDraw(path: Path) {
          // Layer 1 — outermost soft red bloom
          canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = glowW
            strokeCap  = Paint.Cap.ROUND
            color = Color.argb(75, 255, 0, 0)
          })
          // Layer 2 — mid red glow
          canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = midW
            strokeCap  = Paint.Cap.ROUND
            color = Color.argb(195, 255, 20, 0)
          })
          // Layer 3 — bright red (almost solid)
          canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = coreW * 1.7f
            strokeCap  = Paint.Cap.ROUND
            color = Color.argb(255, 255, 65, 30)
          })
          // Layer 4 — white core
          canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = coreW
            strokeCap  = Paint.Cap.ROUND
            color = Color.WHITE
          })
        }

        neonDraw(outerPath)
        neonDraw(innerPath)
      }

      // Positioned above the OUTER ENDS of each eye, lifted high above eyebrows
      // Left horn: cx to the LEFT of left eye (outer end), sweep outward-left
      drawNeonHorn(le.x - eyeDist * 0.22f, eyeMidY - eyeDist * 1.08f, -1f)
      // Right horn: cx to the RIGHT of right eye (outer end), sweep outward-right
      drawNeonHorn(re.x + eyeDist * 0.22f, eyeMidY - eyeDist * 1.08f, +1f)
    }
  }


  // ── Pookie Pink Bows (real image overlay) ────────────────────────────────
  // Draws the bow_pookie.png bitmap above each eye at the same positions
  // as the evil horns (above outer ends of eyes, same height).
  // bowBitmap must be pre-loaded by CameraFilterView (transparent-bg PNG).
  fun drawPinkBows(canvas: Canvas, face: DetectedFace, bowBitmap: Bitmap) {
    val le = leftEye(face)  ?: return
    val re = rightEye(face) ?: return
    val rollAngle = face.rollAngle

    val eyeMidX = (le.x + re.x) / 2f
    val eyeMidY = (le.y + re.y) / 2f
    val eyeDist = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val anchor  = PointF(eyeMidX, eyeMidY)

    // Bow display size: scale so bow width ≈ 0.95 × eye distance
    val bowDisplayW = eyeDist * 0.95f
    val scale       = bowDisplayW / bowBitmap.width.toFloat()
    val bowDisplayH = bowBitmap.height * scale

    // Positions: exactly the same x/y as the evil horn base points
    // Left bow:  above outer end of left eye (sweeps left)
    val lx = le.x - eyeDist * 0.22f   // same as left horn cx
    val ly = eyeMidY - eyeDist * 1.08f // same vertical lift as evil horns
    // Right bow: above outer end of right eye (sweeps right)
    val rx = re.x + eyeDist * 0.22f
    val ry = ly

    val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    withHeadRotation(canvas, anchor, rollAngle) {
      val mat = Matrix()

      // ── Left bow — tilted outward (left side, -25°) ───────────────────────
      mat.reset()
      mat.postScale(scale, scale)
      mat.postTranslate(lx - bowDisplayW / 2f, ly - bowDisplayH / 2f)
      mat.postRotate(-25f, lx, ly)   // rotate around bow centre, tilts left
      canvas.drawBitmap(bowBitmap, mat, bitmapPaint)

      // ── Right bow — tilted outward (right side, +25°) ────────────────────
      mat.reset()
      mat.postScale(scale, scale)
      mat.postTranslate(rx - bowDisplayW / 2f, ry - bowDisplayH / 2f)
      mat.postRotate(25f, rx, ry)    // rotate around bow centre, tilts right
      canvas.drawBitmap(bowBitmap, mat, bitmapPaint)
    }
  }

  // ── Golden Crescent Moons scattered over face ─────────────────────────────
  // Matches the TikTok "dark moon" filter: small gold 🌙 emoji-style crescents
  fun drawCrescentMoons(canvas: Canvas, face: DetectedFace) {
    val box = face.boundingBox
    val faceW = box.width()
    val faceH = box.height()
    val cx = box.centerX()
    val cy = box.centerY()

    val rollAngle = face.rollAngle
    val anchor = PointF(cx, cy)

    // Gold paint
    val goldPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color  = Color.argb(235, 255, 205, 20)
      style  = Paint.Style.FILL
    }

    // Relative coordinates based on face box coordinates (-0.5 to 0.5):
    // Triple(rx, ry, sizeMult)
    val moons = listOf(
      Triple(-0.24f, -0.42f, 1.00f),  // high forehead left
      Triple(-0.06f, -0.32f, 0.85f),  // mid forehead center-left
      Triple( 0.20f, -0.40f, 0.95f),  // forehead right
      Triple( 0.32f, -0.25f, 1.00f),  // temple right (pulled in from 0.38)
      Triple(-0.30f, -0.15f, 0.80f),  // above left eye / brow
      Triple(-0.04f, -0.05f, 0.70f),  // nose bridge center
      Triple( 0.05f,  0.22f, 0.80f),  // lower nose / upper cheek
      Triple(-0.35f,  0.06f, 0.90f),  // outer left cheek (pulled in from -0.43)
      Triple( 0.32f,  0.13f, 0.95f),  // outer right cheek (pulled in from 0.38)
      Triple(-0.33f,  0.26f, 0.85f),  // lower left jaw (pulled in from -0.40)
      Triple( 0.24f,  0.36f, 0.85f),  // lower right jaw (pulled in from 0.28)
      Triple(-0.16f,  0.44f, 0.90f),  // chin area
    )

    // Base radius scales with face width
    val baseR = faceW * 0.038f

    withHeadRotation(canvas, anchor, rollAngle) {
      for ((rx, ry, sz) in moons) {
        val px = cx + rx * faceW
        val py = cy + ry * faceH
        val outerR = baseR * sz
        val innerR = outerR * 0.68f
        val offX   = outerR * 0.38f

        // EVEN_ODD: outer circle minus offset inner circle = crescent 🌙
        val path = Path().apply {
          fillType = Path.FillType.EVEN_ODD
          addCircle(px, py, outerR, Path.Direction.CW)
          addCircle(px + offX, py - offX * 0.12f, innerR, Path.Direction.CW)
        }
        canvas.drawPath(path, goldPaint)
      }
    }
  }

  private fun heartPath(cx: Float, cy: Float, w: Float, h: Float): Path {
    return Path().apply {
      moveTo(cx, cy + h * 0.35f)
      cubicTo(
        cx - w * 0.45f, cy - h * 0.08f,
        cx - w * 0.40f, cy - h * 0.45f,
        cx - w * 0.12f, cy - h * 0.45f,
      )
      cubicTo(
        cx, cy - h * 0.45f,
        cx, cy - h * 0.10f,
        cx, cy - h * 0.10f,
      )
      cubicTo(
        cx, cy - h * 0.10f,
        cx, cy - h * 0.45f,
        cx + w * 0.12f, cy - h * 0.45f,
      )
      cubicTo(
        cx + w * 0.40f, cy - h * 0.45f,
        cx + w * 0.45f, cy - h * 0.08f,
        cx, cy + h * 0.35f,
      )
      close()
    }
  }

  private fun drawGlow(canvas: Canvas, cx: Float, cy: Float, radius: Float, tint: Int) {
    val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        cx, cy, radius,
        intArrayOf(tint, Color.TRANSPARENT),
        floatArrayOf(0f, 1f),
        Shader.TileMode.CLAMP,
      )
    }
    canvas.drawCircle(cx, cy, radius, glowPaint)
  }

  fun drawPinkHearts(canvas: Canvas, face: DetectedFace) {
    val box = face.boundingBox
    val faceW = box.width()
    val faceH = box.height()
    val cx = box.centerX()
    val top = topOfHeadPoint(face)
    val foreheadY = (top?.y ?: box.top) - faceH * 0.15f
    val anchor = PointF(cx, foreheadY)
    val rollAngle = face.rollAngle
    val time = SystemClock.uptimeMillis().toFloat()
    val floatPhase = time / 1600f

    val heartColor = Color.argb(220, 255, 65, 155)
    // Relative positions tuned to blanket the full head silhouette from the front hairline down
    // to the forehead area.
    val hearts = listOf(
      Triple(-0.48f, -0.20f, 1.00f),
      Triple(-0.34f, -0.24f, 1.00f),
      Triple(-0.20f, -0.27f, 1.00f),
      Triple(-0.06f, -0.28f, 1.00f),
      Triple( 0.08f, -0.27f, 1.00f),
      Triple( 0.22f, -0.24f, 1.00f),
      Triple( 0.36f, -0.20f, 1.00f),
      Triple(-0.50f, -0.02f, 1.00f),
      Triple(-0.36f, -0.05f, 1.00f),
      Triple(-0.22f, -0.06f, 1.00f),
      Triple(-0.08f, -0.07f, 1.00f),
      Triple( 0.06f, -0.06f, 1.00f),
      Triple( 0.20f, -0.05f, 1.00f),
      Triple( 0.34f, -0.02f, 1.00f),
      Triple(-0.46f,  0.16f, 1.00f),
      Triple(-0.31f,  0.12f, 1.00f),
      Triple(-0.16f,  0.10f, 1.00f),
      Triple(-0.01f,  0.09f, 1.00f),
      Triple( 0.14f,  0.10f, 1.00f),
      Triple( 0.29f,  0.12f, 1.00f),
      Triple( 0.44f,  0.16f, 1.00f),
    )

    withHeadRotation(canvas, anchor, rollAngle) {
      hearts.forEachIndexed { index, (rx, ry, scale) ->
        val risePhase = (floatPhase + index * 0.08f) % 1f
        val rise = risePhase * faceH * 0.10f
        val floatX = kotlin.math.cos(floatPhase * 0.45f + index * 0.65f) * faceW * 0.002f
        val bobY = kotlin.math.sin(index * 0.92f + floatPhase * 0.75f) * faceH * 0.045f
        val heartCx = cx + rx * faceW + floatX
        val heartCy = foreheadY + ry * faceH + bobY - rise
        val heartW = faceW * 0.092f
        val heartH = heartW * 1.06f
        val rotation = when (index % 4) {
          0 -> -7f
          1 -> -2f
          2 -> 3f
          else -> 8f
        }

        canvas.save()
        canvas.rotate(rotation, heartCx, heartCy)
        val heartPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
          color = heartColor
          style = Paint.Style.FILL
        }
        canvas.drawPath(heartPath(heartCx, heartCy, heartW, heartH), heartPaint)
        canvas.restore()
      }
    }
  }

  private fun butterflyPath(cx: Float, cy: Float, size: Float, flutterScale: Float): Path {
    val path = Path()
    // Left wings (sweeping left/negative X)
    path.moveTo(cx, cy)
    // Top-left wing
    path.cubicTo(
      cx - size * 0.9f * flutterScale, cy - size * 0.7f,
      cx - size * 1.1f * flutterScale, cy - size * 0.1f,
      cx - size * 0.1f * flutterScale, cy + size * 0.1f
    )
    // Bottom-left wing
    path.cubicTo(
      cx - size * 0.8f * flutterScale, cy + size * 0.4f,
      cx - size * 0.4f * flutterScale, cy + size * 0.5f,
      cx, cy
    )
    // Right wings (sweeping right/positive X)
    path.moveTo(cx, cy)
    // Top-right wing
    path.cubicTo(
      cx + size * 0.9f * flutterScale, cy - size * 0.7f,
      cx + size * 1.1f * flutterScale, cy - size * 0.1f,
      cx + size * 0.1f * flutterScale, cy + size * 0.1f
    )
    // Bottom-right wing
    path.cubicTo(
      cx + size * 0.8f * flutterScale, cy + size * 0.4f,
      cx + size * 0.4f * flutterScale, cy + size * 0.5f,
      cx, cy
    )
    path.close()
    return path
  }

  fun drawButterflies(canvas: Canvas, face: DetectedFace) {
    val box = face.boundingBox
    val faceW = box.width()
    val faceH = box.height()
    val cx = box.centerX()
    val top = topOfHeadPoint(face)
    val foreheadY = (top?.y ?: box.top) + faceH * 0.03f
    val anchor = PointF(cx, foreheadY)
    val rollAngle = face.rollAngle
    val time = SystemClock.uptimeMillis().toFloat()
    val floatPhase = time / 1400f

    // Relative positions surrounding the head crown and sides
    val butterflies = listOf(
      Triple(-0.45f, -0.25f, 1.0f),
      Triple(-0.25f, -0.32f, 0.9f),
      Triple( 0.00f, -0.36f, 1.1f),
      Triple( 0.25f, -0.32f, 0.9f),
      Triple( 0.45f, -0.25f, 1.0f),
      Triple(-0.55f, -0.05f, 0.8f),
      Triple(-0.35f, -0.10f, 1.0f),
      Triple(-0.12f, -0.15f, 0.9f),
      Triple( 0.12f, -0.15f, 0.9f),
      Triple( 0.35f, -0.10f, 1.0f),
      Triple( 0.55f, -0.05f, 0.8f),
      Triple(-0.40f,  0.10f, 0.7f),
      Triple(-0.20f,  0.05f, 0.8f),
      Triple( 0.00f,  0.02f, 1.0f),
      Triple( 0.20f,  0.05f, 0.8f),
      Triple( 0.40f,  0.10f, 0.7f)
    )

    withHeadRotation(canvas, anchor, rollAngle) {
      butterflies.forEachIndexed { index, (rx, ry, baseScale) ->
        val risePhase = (floatPhase + index * 0.065f) % 1f
        val rise = risePhase * faceH * 0.16f
        val floatX = kotlin.math.cos(floatPhase * 0.5f + index * 0.7f) * faceW * 0.025f
        val bobY = kotlin.math.sin(index * 0.8f + floatPhase * 0.6f) * faceH * 0.035f
        
        val bCx = cx + rx * faceW + floatX
        val bCy = foreheadY + ry * faceH + bobY - rise
        val bSize = faceW * 0.08f * baseScale
        
        // Flutter scale cycles wings from closed to open
        val flutterScale = 0.25f + 0.75f * kotlin.math.abs(kotlin.math.sin(time * 0.018f + index * 1.3f))
        
        val alpha = (240 * (1f - risePhase)).toInt().coerceIn(0, 255)

        // Draw soft glow behind the butterfly
        drawGlow(canvas, bCx, bCy, bSize * 1.8f, Color.argb(alpha / 4, 255, 255, 255))

        canvas.save()
        // Slight natural rotation of the butterfly body
        val tilt = kotlin.math.sin(time * 0.005f + index) * 15f
        canvas.rotate(tilt.toFloat(), bCx, bCy)

        val bPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
          color = Color.argb(alpha, 255, 255, 255)
          style = Paint.Style.FILL
        }
        val path = butterflyPath(bCx, bCy, bSize, flutterScale)
        canvas.drawPath(path, bPaint)

        // Add a thin bright border
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
          color = Color.argb(alpha, 250, 250, 255)
          style = Paint.Style.STROKE
          strokeWidth = bSize * 0.08f
        }
        canvas.drawPath(path, borderPaint)

        canvas.restore()
      }
    }
  }

  private fun lensRect(cx: Float, cy: Float, w: Float, h: Float) =
    RectF(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)


  private fun drawLensGlass(canvas: Canvas, rect: RectF, cornerRadius: Float, glassStyle: GlassStyleType) {
    val glassPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    when (glassStyle) {
      GlassStyleType.SUN -> {
        glassPaint.shader = LinearGradient(
          rect.left, rect.top, rect.left, rect.bottom,
          intArrayOf(Color.argb(0xFA, 0x11, 0x11, 0x13), Color.argb(0xD0, 0x22, 0x22, 0x28)),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
      GlassStyleType.SPORT -> {
        glassPaint.shader = LinearGradient(
          rect.left, rect.top, rect.right, rect.bottom,
          intArrayOf(Color.argb(0xCC, 0x00, 0xe5, 0xff), Color.argb(0xCC, 0xbd, 0x00, 0xff)),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
      GlassStyleType.HEART -> {
        glassPaint.shader = LinearGradient(
          rect.left, rect.top, rect.left, rect.bottom,
          intArrayOf(Color.argb(0x99, 0xff, 0x4d, 0x6d), Color.argb(0x40, 0xff, 0xb3, 0xc1)),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
      else -> {
        glassPaint.shader = LinearGradient(
          rect.left, rect.top, rect.left, rect.bottom,
          intArrayOf(Color.argb(0x8C, 0x18, 0x18, 0x1C), Color.argb(0x50, 0x40, 0x40, 0x48)),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
    }

    if (glassStyle == GlassStyleType.HEART) {
      val heart = Path()
      val w = rect.width()
      val h = rect.height()
      val cx = rect.centerX()
      val cy = rect.centerY()
      heart.moveTo(cx, cy + h * 0.35f)
      heart.cubicTo(cx - w * 0.45f, cy - h * 0.1f, cx - w * 0.4f, cy - h * 0.45f, cx - w * 0.15f, cy - h * 0.45f)
      heart.cubicTo(cx, cy - h * 0.45f, cx, cy - h * 0.1f, cx, cy - h * 0.1f)
      heart.cubicTo(cx, cy - h * 0.1f, cx, cy - h * 0.45f, cx + w * 0.15f, cy - h * 0.45f)
      heart.cubicTo(cx + w * 0.4f, cy - h * 0.45f, cx + w * 0.45f, cy - h * 0.1f, cx, cy + h * 0.35f)
      heart.close()
      canvas.drawPath(heart, glassPaint)
      
      val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(0x55, 0xFF, 0xFF, 0xFF) }
      canvas.drawCircle(cx - w * 0.18f, cy - h * 0.22f, w * 0.08f, highlightPaint)
    } else {
      canvas.drawRoundRect(rect, cornerRadius, cornerRadius, glassPaint)
      
      // Specular highlight streak
      val highlight = Path()
      val hw = rect.width() * 0.22f
      val hh = rect.height() * 0.5f
      val hx = rect.left + rect.width() * 0.28f
      val hy = rect.top + rect.height() * 0.32f
      highlight.addOval(RectF(hx - hw / 2, hy - hh / 2, hx + hw / 2, hy + hh / 2), Path.Direction.CW)
      val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(0x55, 0xFF, 0xFF, 0xFF) }
      canvas.drawPath(highlight, highlightPaint)
    }
  }

  fun drawGlasses(canvas: Canvas, face: DetectedFace, glassStyle: GlassStyleType = GlassStyleType.CLASSIC) {
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val rollAngle = face.rollAngle

    val eyeDistance = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val lensW = eyeDistance * 0.82f
    val lensH = eyeDistance * 0.62f
    val cornerRadius = lensH * 0.4f
    val frameWidth = eyeDistance * 0.05f
    
    val centerX = (le.x + re.x) / 2
    val centerY = (le.y + re.y) / 2
    val anchor = PointF(centerX, centerY)

    // Define lens positions horizontally symmetric relative to centerX and centerY
    val leftLens = lensRect(centerX - eyeDistance * 0.46f, centerY, lensW, lensH)
    val rightLens = lensRect(centerX + eyeDistance * 0.46f, centerY, lensW, lensH)

    val yawRad = Math.toRadians(face.yawAngle.toDouble()).toFloat()
    val pitchRad = Math.toRadians(face.pitchAngle.toDouble()).toFloat()

    withHeadRotation(canvas, anchor, rollAngle) {
      val armPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = when (glassStyle) {
          GlassStyleType.SPORT -> Color.parseColor("#39ff14")
          GlassStyleType.HEART -> Color.parseColor("#ff2a2a")
          else -> Color.parseColor("#1c1c1e")
        }
        this.style = Paint.Style.STROKE
        strokeWidth = frameWidth * 0.85f
        strokeCap = Paint.Cap.ROUND
      }

      // Left temple arm (adjustable to actual ear coordinate if detected)
      val leftArmEnd = if (face.leftEar != null) {
        val pt = getLocalPoint(face.leftEar, anchor, rollAngle)
        PointF(pt.x, pt.y - eyeDistance * 0.32f)
      } else {
        PointF(centerX - eyeDistance * 1.25f * (1.0f - yawRad * 0.3f), centerY - eyeDistance * 0.38f + pitchRad * eyeDistance * 0.2f)
      }

      if (face.yawAngle >= -20f) {
        canvas.drawLine(leftLens.left, centerY, leftArmEnd.x, leftArmEnd.y, armPaint)
      }

      // Right temple arm (adjustable to actual ear coordinate if detected)
      val rightArmEnd = if (face.rightEar != null) {
        val pt = getLocalPoint(face.rightEar, anchor, rollAngle)
        PointF(pt.x, pt.y - eyeDistance * 0.32f)
      } else {
        PointF(centerX + eyeDistance * 1.25f * (1.0f + yawRad * 0.3f), centerY - eyeDistance * 0.38f + pitchRad * eyeDistance * 0.2f)
      }

      if (face.yawAngle <= 20f) {
        canvas.drawLine(rightLens.right, centerY, rightArmEnd.x, rightArmEnd.y, armPaint)
      }

      // Bridge connecting the lenses
      val bridgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = when (glassStyle) {
          GlassStyleType.SPORT -> Color.parseColor("#39ff14")
          GlassStyleType.HEART -> Color.parseColor("#ff2a2a")
          else -> Color.parseColor("#1c1c1e")
        }
        this.style = Paint.Style.STROKE
        strokeWidth = frameWidth * 0.8f
        strokeCap = Paint.Cap.ROUND
      }
      val bridge = Path()
      val midY = centerY - lensH * 0.12f
      bridge.moveTo(leftLens.right, centerY - lensH * 0.05f)
      bridge.quadTo(centerX, midY, rightLens.left, centerY - lensH * 0.05f)
      canvas.drawPath(bridge, bridgePaint)

      // Draw glass
      drawLensGlass(canvas, leftLens, cornerRadius, glassStyle)
      drawLensGlass(canvas, rightLens, cornerRadius, glassStyle)

      // Frames
      val framePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        val c1 = when (glassStyle) {
          GlassStyleType.SPORT -> "#39ff14"
          GlassStyleType.HEART -> "#ff2a2a"
          GlassStyleType.RETRO -> "#ffffff"
          else -> "#2c2c2e"
        }
        val c2 = when (glassStyle) {
          GlassStyleType.SPORT -> "#00e5ff"
          GlassStyleType.HEART -> "#ff8a8a"
          GlassStyleType.RETRO -> "#d4af37"
          else -> "#0a0a0b"
        }
        shader = LinearGradient(
          0f, leftLens.top, 0f, leftLens.bottom,
          intArrayOf(Color.parseColor(c1), Color.parseColor(c2)),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
        )
        this.style = Paint.Style.STROKE
        strokeWidth = frameWidth
        strokeJoin = Paint.Join.ROUND
      }

      if (glassStyle == GlassStyleType.HEART) {
        fun drawHeartFrame(rect: RectF) {
          val heart = Path()
          val w = rect.width()
          val h = rect.height()
          val cx = rect.centerX()
          val cy = rect.centerY()
          heart.moveTo(cx, cy + h * 0.35f)
          heart.cubicTo(cx - w * 0.45f, cy - h * 0.1f, cx - w * 0.4f, cy - h * 0.45f, cx - w * 0.15f, cy - h * 0.45f)
          heart.cubicTo(cx, cy - h * 0.45f, cx, cy - h * 0.1f, cx, cy - h * 0.1f)
          heart.cubicTo(cx, cy - h * 0.1f, cx, cy - h * 0.45f, cx + w * 0.15f, cy - h * 0.45f)
          heart.cubicTo(cx + w * 0.4f, cy - h * 0.45f, cx + w * 0.45f, cy - h * 0.1f, cx, cy + h * 0.35f)
          heart.close()
          canvas.drawPath(heart, framePaint)
        }
        drawHeartFrame(leftLens)
        drawHeartFrame(rightLens)
      } else {
        canvas.drawRoundRect(leftLens, cornerRadius, cornerRadius, framePaint)
        canvas.drawRoundRect(rightLens, cornerRadius, cornerRadius, framePaint)
      }
    }
  }

  fun drawHat(canvas: Canvas, face: DetectedFace, hatStyle: HatStyleType = HatStyleType.WIZARD) {
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val rollAngle = face.rollAngle

    val eyeDistance = if (face.smoothedEyeDistance > 0f) face.smoothedEyeDistance else eyeDistance(face)
    val centerX = (le.x + re.x) / 2
    val centerY = (le.y + re.y) / 2
    val anchor = PointF(centerX, centerY)

    // 3D perspective translation (parallax) based on head yaw and pitch angles
    val yawRad = Math.toRadians(face.yawAngle.toDouble()).toFloat()
    val pitchRad = Math.toRadians(face.pitchAngle.toDouble()).toFloat()
    val cosYaw = kotlin.math.cos(yawRad.toDouble()).toFloat().coerceIn(0.5f, 1.0f)

    val baseOffsetX = -yawRad * eyeDistance * 0.15f
    val baseOffsetY = pitchRad * eyeDistance * 0.15f

    // Define brim height relative to face center in local coordinates
    // Increased the negative offset to push hats significantly higher above the head
    val localBrimY = centerY - eyeDistance * when (hatStyle) {
      HatStyleType.WIZARD -> 1.55f
      HatStyleType.COWBOY -> 1.45f
      HatStyleType.SANTA -> 1.35f
    }

    val brimX = centerX + baseOffsetX
    val brimY = localBrimY + baseOffsetY

    if (hatStyle == HatStyleType.SANTA) {
      withHeadRotation(canvas, anchor, rollAngle) {
        drawSantaBeardAndMustache(canvas, face, centerX, centerY, eyeDistance)
      }
    }

    withHeadRotation(canvas, anchor, rollAngle) {
      when (hatStyle) {
        HatStyleType.WIZARD -> {
          val hatWidth = eyeDistance * 2.2f
          val hatHeight = eyeDistance * 2.2f
          val brimW = hatWidth * 1.15f * cosYaw
          val brimH = eyeDistance * 0.38f * (1.0f + kotlin.math.abs(pitchRad) * 0.8f)

          val crownOffsetX = -yawRad * eyeDistance * 0.7f
          val crownOffsetY = pitchRad * eyeDistance * 0.7f

          val conePath = Path()
          conePath.moveTo(brimX + baseOffsetX - hatWidth * 0.35f * cosYaw, brimY + baseOffsetY + brimH * 0.1f)
          val tipX = brimX + crownOffsetX - hatWidth * 0.12f * cosYaw
          val tipY = brimY - hatHeight + crownOffsetY
          conePath.cubicTo(
            brimX + baseOffsetX - hatWidth * 0.3f * cosYaw, brimY + baseOffsetY - hatHeight * 0.6f,
            brimX + crownOffsetX - hatWidth * 0.2f * cosYaw, brimY + crownOffsetY - hatHeight * 0.95f,
            tipX, tipY
          )
          conePath.cubicTo(
            brimX + crownOffsetX + hatWidth * 0.05f * cosYaw, brimY + crownOffsetY - hatHeight * 0.85f,
            brimX + baseOffsetX + hatWidth * 0.25f * cosYaw, brimY + baseOffsetY - hatHeight * 0.5f,
            brimX + baseOffsetX + hatWidth * 0.35f * cosYaw, brimY + baseOffsetY + brimH * 0.1f
          )
          conePath.quadTo(brimX + baseOffsetX, brimY + baseOffsetY + brimH * 0.25f, brimX + baseOffsetX - hatWidth * 0.35f * cosYaw, brimY + baseOffsetY + brimH * 0.1f)
          conePath.close()

          val conePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
              brimX + baseOffsetX - hatWidth * 0.35f, brimY - hatHeight,
              brimX + baseOffsetX + hatWidth * 0.35f, brimY + brimH * 0.25f,
              intArrayOf(Color.parseColor("#4a0ca3"), Color.parseColor("#7209b7"), Color.parseColor("#3f51b5")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawPath(conePath, conePaint)

          // Stars
          val starPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#f5c542")
            this.style = Paint.Style.FILL
          }
          fun drawSurfStar(tDepth: Float, dx: Float, dy: Float, radius: Float) {
            val sx = brimX + (baseOffsetX + (crownOffsetX - baseOffsetX) * tDepth) + dx * cosYaw
            val sy = brimY + (baseOffsetY + (crownOffsetY - baseOffsetY) * tDepth) - hatHeight * tDepth + dy
            val path = Path()
            val points = 5
            for (i in 0 until points * 2) {
              val r = if (i % 2 == 0) radius else radius * 0.4f
              val angle = (i * Math.PI / points).toFloat() - (Math.PI / 2).toFloat()
              val px = sx + cos(angle) * r
              val py = sy + sin(angle) * r
              if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
            }
            path.close()
            canvas.drawPath(path, starPaint)
          }
          drawSurfStar(0.65f, -hatWidth * 0.1f, 0f, eyeDistance * 0.11f)
          drawSurfStar(0.40f, hatWidth * 0.12f, 0f, eyeDistance * 0.13f)
          drawSurfStar(0.25f, -hatWidth * 0.15f, 0f, eyeDistance * 0.09f)
          drawSurfStar(0.72f, hatWidth * 0.05f, 0f, eyeDistance * 0.08f)

          // Brim
          val brimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
              brimX - brimW / 2, brimY,
              brimX + brimW / 2, brimY,
              intArrayOf(Color.parseColor("#31106a"), Color.parseColor("#4a0ca3"), Color.parseColor("#1f004a")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawOval(RectF(brimX - brimW / 2, brimY - brimH * 0.4f, brimX + brimW / 2, brimY + brimH * 0.6f), brimPaint)
        }

        HatStyleType.COWBOY -> {
          val crownW = eyeDistance * 1.8f * cosYaw
          val crownH = eyeDistance * 1.4f
          val crownOffsetX = -yawRad * eyeDistance * 0.35f
          val crownOffsetY = pitchRad * eyeDistance * 0.35f
          val crownTopY = brimY - crownH

          val crownPath = Path()
          crownPath.moveTo(brimX + crownOffsetX - crownW * 0.44f, brimY + crownOffsetY + crownH * 0.08f)
          crownPath.cubicTo(
            brimX + crownOffsetX - crownW * 0.48f, brimY + crownOffsetY - crownH * 0.5f,
            brimX + crownOffsetX - crownW * 0.35f, crownTopY + crownOffsetY - crownH * 0.05f,
            brimX + crownOffsetX - crownW * 0.22f, crownTopY + crownOffsetY
          )
          crownPath.quadTo(brimX + crownOffsetX, crownTopY + crownOffsetY + crownH * 0.12f, brimX + crownOffsetX + crownW * 0.22f, crownTopY + crownOffsetY)
          crownPath.cubicTo(
            brimX + crownOffsetX + crownW * 0.35f, crownTopY + crownOffsetY - crownH * 0.05f,
            brimX + crownOffsetX + crownW * 0.48f, brimY + crownOffsetY - crownH * 0.5f,
            brimX + crownOffsetX + crownW * 0.44f, brimY + crownOffsetY + crownH * 0.08f
          )
          crownPath.quadTo(brimX + crownOffsetX, brimY + crownOffsetY + crownH * 0.16f, brimX + crownOffsetX - crownW * 0.44f, brimY + crownOffsetY + crownH * 0.08f)
          crownPath.close()

          val crownPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
              brimX + crownOffsetX - crownW / 2, brimY + crownOffsetY - crownH,
              brimX + crownOffsetX + crownW / 2, brimY + crownOffsetY,
              intArrayOf(Color.parseColor("#a0522d"), Color.parseColor("#8b5a2b"), Color.parseColor("#5c2e0b")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawPath(crownPath, crownPaint)

          // Hatband
          val bandH = eyeDistance * 0.12f
          val bandPath = Path()
          bandPath.moveTo(brimX + crownOffsetX - crownW * 0.43f, brimY + crownOffsetY + crownH * 0.07f)
          bandPath.quadTo(brimX + crownOffsetX, brimY + crownOffsetY + crownH * 0.14f, brimX + crownOffsetX + crownW * 0.43f, brimY + crownOffsetY + crownH * 0.07f)
          bandPath.lineTo(brimX + crownOffsetX + crownW * 0.43f, brimY + crownOffsetY + crownH * 0.15f)
          bandPath.quadTo(brimX + crownOffsetX, brimY + crownOffsetY + crownH * 0.22f, brimX + crownOffsetX - crownW * 0.43f, brimY + crownOffsetY + crownH * 0.15f)
          bandPath.close()
          canvas.drawPath(bandPath, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#2a1508") })

          // Brim
          val brimW = eyeDistance * 2.8f * cosYaw
          val brimH = eyeDistance * 0.42f * (1.0f + kotlin.math.abs(pitchRad) * 0.8f)
          val brimPath = Path()
          brimPath.moveTo(brimX - brimW / 2, brimY - brimH * 0.4f)
          brimPath.quadTo(brimX, brimY + brimH * 0.35f, brimX + brimW / 2, brimY - brimH * 0.4f)
          brimPath.quadTo(brimX + brimW / 2 + eyeDistance * 0.08f, brimY - brimH * 0.1f, brimX + brimW / 2, brimY)
          brimPath.quadTo(brimX, brimY + brimH * 0.75f, brimX - brimW / 2, brimY)
          brimPath.quadTo(brimX - brimW / 2 - eyeDistance * 0.08f, brimY - brimH * 0.1f, brimX - brimW / 2, brimY - brimH * 0.4f)
          brimPath.close()

          val brimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
              brimX - brimW / 2, brimY,
              brimX + brimW / 2, brimY,
              intArrayOf(Color.parseColor("#703612"), Color.parseColor("#8b5a2b"), Color.parseColor("#5c2e0b")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawPath(brimPath, brimPaint)
        }

        HatStyleType.SANTA -> {
          val trimW = eyeDistance * 2.2f * cosYaw
          val trimH = eyeDistance * 0.38f * (1.0f + kotlin.math.abs(pitchRad) * 0.8f)
          val redH = eyeDistance * 1.8f

          val crownOffsetX = -yawRad * eyeDistance * 0.7f
          val crownOffsetY = pitchRad * eyeDistance * 0.7f

          val redPath = Path()
          redPath.moveTo(brimX - trimW * 0.42f, brimY - trimH * 0.3f)

          val pomX = brimX + trimW * 0.32f + crownOffsetX
          val pomY = brimY - redH * 0.14f + crownOffsetY

          redPath.cubicTo(
            brimX - trimW * 0.35f, brimY - redH * 0.7f + crownOffsetY * 0.5f,
            brimX - trimW * 0.05f + crownOffsetX * 0.8f, brimY - redH * 0.98f + crownOffsetY,
            pomX - eyeDistance * 0.16f, pomY - eyeDistance * 0.08f
          )
          redPath.lineTo(pomX, pomY)
          redPath.cubicTo(
            brimX + trimW * 0.2f + crownOffsetX * 0.6f, brimY - redH * 0.45f + crownOffsetY * 0.6f,
            brimX + trimW * 0.1f, brimY - redH * 0.65f,
            brimX, brimY - redH * 0.45f
          )
          redPath.quadTo(brimX, brimY - trimH * 0.1f, brimX - trimW * 0.42f, brimY - trimH * 0.3f)
          redPath.close()

          val redPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
              brimX - trimW * 0.4f, brimY - redH + crownOffsetY,
              brimX + trimW * 0.4f, brimY,
              intArrayOf(Color.parseColor("#ff1e27"), Color.parseColor("#d90429"), Color.parseColor("#9b001c")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawPath(redPath, redPaint)

          // White fur trim cylinder
          val trimPath = Path()
          trimPath.moveTo(brimX - trimW / 2, brimY - trimH * 0.4f)
          trimPath.quadTo(brimX, brimY - trimH * 0.1f, brimX + trimW / 2, brimY - trimH * 0.4f)
          trimPath.lineTo(brimX + trimW / 2, brimY + trimH * 0.2f)
          trimPath.quadTo(brimX, brimY + trimH * 0.5f, brimX - trimW / 2, brimY + trimH * 0.2f)
          trimPath.close()

          val trimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
              brimX, brimY - trimH,
              brimX, brimY + trimH,
              intArrayOf(Color.parseColor("#ffffff"), Color.parseColor("#f5f5f7"), Color.parseColor("#d9d9e3")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawPath(trimPath, trimPaint)

          // White Pom-pom
          val pomR = eyeDistance * 0.25f
          val pomPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
              pomX - pomR * 0.2f, pomY - pomR * 0.2f, pomR * 1.2f,
              intArrayOf(Color.parseColor("#ffffff"), Color.parseColor("#e6e6fa"), Color.parseColor("#ccd0d9")),
              null, Shader.TileMode.CLAMP
            )
          }
          canvas.drawCircle(pomX, pomY, pomR, pomPaint)
        }
      }
    }
  }

  private fun drawSantaBeardAndMustache(
    canvas: Canvas,
    face: DetectedFace,
    centerX: Float,
    centerY: Float,
    eyeDistance: Float
  ) {
    fun averageY(points: List<PointF>?): Float? {
      if (points.isNullOrEmpty()) return null
      var total = 0f
      for (point in points) {
        total += point.y
      }
      return total / points.size.toFloat()
    }

    val box = face.boundingBox
    val noseY = noseBase(face)?.y ?: (centerY + eyeDistance * 0.55f)
    val mouthY = averageY(face.lowerLip) ?: averageY(face.upperLip) ?: (centerY + eyeDistance * 0.82f)
    val chin = bottomOfFacePoint(face)
    val chinX = chin?.x ?: box.centerX()
    val chinY = chin?.y ?: (box.bottom - eyeDistance * 0.04f)

    val cheekPadding = eyeDistance * 0.18f
    val beardHalfWidth = max(box.width() * 0.42f, eyeDistance * 1.15f)
    val beardLeftX = (leftCheek(face)?.x ?: (centerX - beardHalfWidth)) - cheekPadding
    val beardRightX = (rightCheek(face)?.x ?: (centerX + beardHalfWidth)) + cheekPadding
    val beardTopY = max(noseY + eyeDistance * 0.30f, mouthY + eyeDistance * 0.02f)
    val beardBottomY = max(chinY + eyeDistance * 0.06f, mouthY + eyeDistance * 0.70f)
    val beardUpperDipY = beardTopY + eyeDistance * 0.08f

    val beardPath = Path()
    beardPath.moveTo(beardLeftX, beardTopY)
    beardPath.cubicTo(
      beardLeftX - eyeDistance * 0.22f, beardTopY + eyeDistance * 0.42f,
      chinX - eyeDistance * 0.42f, beardBottomY - eyeDistance * 0.18f,
      chinX, beardBottomY
    )
    beardPath.cubicTo(
      chinX + eyeDistance * 0.42f, beardBottomY - eyeDistance * 0.18f,
      beardRightX + eyeDistance * 0.22f, beardTopY + eyeDistance * 0.42f,
      beardRightX, beardTopY
    )
    beardPath.quadTo(beardRightX - eyeDistance * 0.14f, beardUpperDipY, centerX, beardUpperDipY + eyeDistance * 0.02f)
    beardPath.quadTo(beardLeftX + eyeDistance * 0.14f, beardUpperDipY, beardLeftX, beardTopY)
    beardPath.close()

    val beardPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      this.style = Paint.Style.FILL
    }
    val beardBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#e6e6fa") // subtle gray-blue shadow border
      this.style = Paint.Style.STROKE
      strokeWidth = eyeDistance * 0.035f
    }

    canvas.drawPath(beardPath, beardPaint)
    canvas.drawPath(beardPath, beardBorderPaint)

    // 2. Draw fluffy cloud circles along the outer contour to make it cartoonish/3D
    val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      this.style = Paint.Style.FILL
    }
    fun getCubicPoint(p0: PointF, p1: PointF, p2: PointF, p3: PointF, t: Float): PointF {
      val mt = 1f - t
      val x = mt * mt * mt * p0.x + 3 * mt * mt * t * p1.x + 3 * mt * t * t * p2.x + t * t * t * p3.x
      val y = mt * mt * mt * p0.y + 3 * mt * mt * t * p1.y + 3 * mt * t * t * p2.y + t * t * t * p3.y
      return PointF(x, y)
    }

    val leftP0 = PointF(beardLeftX, beardTopY)
    val leftP1 = PointF(beardLeftX - eyeDistance * 0.22f, beardTopY + eyeDistance * 0.42f)
    val leftP2 = PointF(chinX - eyeDistance * 0.42f, beardBottomY - eyeDistance * 0.18f)
    val leftP3 = PointF(chinX, beardBottomY)

    val rightP0 = PointF(chinX, beardBottomY)
    val rightP1 = PointF(chinX + eyeDistance * 0.42f, beardBottomY - eyeDistance * 0.18f)
    val rightP2 = PointF(beardRightX + eyeDistance * 0.22f, beardTopY + eyeDistance * 0.42f)
    val rightP3 = PointF(beardRightX, beardTopY)

    val steps = 6
    for (i in 0..steps) {
      val t = i.toFloat() / steps.toFloat()
      val leftPt = getCubicPoint(leftP0, leftP1, leftP2, leftP3, t)
      val rightPt = getCubicPoint(rightP0, rightP1, rightP2, rightP3, t)

      val r = eyeDistance * (0.24f + 0.12f * sin(t * Math.PI).toFloat())
      canvas.drawCircle(leftPt.x, leftPt.y, r, detailPaint)
      canvas.drawCircle(leftPt.x, leftPt.y, r, beardBorderPaint)
      canvas.drawCircle(rightPt.x, rightPt.y, r, detailPaint)
      canvas.drawCircle(rightPt.x, rightPt.y, r, beardBorderPaint)
    }

    // Re-fill interior of beard to cover inside lines
    canvas.drawPath(beardPath, beardPaint)

    // 3. Draw Mustache right under the nose base in local coordinates
    val mcX = centerX
    val mcY = noseY + eyeDistance * 0.02f
    val mlX = centerX - eyeDistance * 0.40f
    val mlY = noseY + eyeDistance * 0.14f
    val mrX = centerX + eyeDistance * 0.40f
    val mrY = noseY + eyeDistance * 0.14f

    val leftMustache = Path()
    leftMustache.moveTo(mcX, mcY)
    leftMustache.quadTo(mcX - eyeDistance * 0.22f, mcY - eyeDistance * 0.15f, mlX, mlY)
    leftMustache.quadTo(mcX - eyeDistance * 0.24f, mcY + eyeDistance * 0.11f, mcX, mcY)
    leftMustache.close()

    val rightMustache = Path()
    rightMustache.moveTo(mcX, mcY)
    rightMustache.quadTo(mcX + eyeDistance * 0.22f, mcY - eyeDistance * 0.15f, mrX, mrY)
    rightMustache.quadTo(mcX + eyeDistance * 0.24f, mcY + eyeDistance * 0.11f, mcX, mcY)
    rightMustache.close()

     canvas.drawPath(leftMustache, beardPaint)
    canvas.drawPath(leftMustache, beardBorderPaint)
    canvas.drawPath(rightMustache, beardPaint)
    canvas.drawPath(rightMustache, beardBorderPaint)
  }

  private fun sketchedHeartPath(cx: Float, cy: Float, w: Float, h: Float): Path {
    val path = Path()
    path.moveTo(cx, cy + h * 0.35f)
    path.cubicTo(cx - w * 0.45f, cy - h * 0.1f, cx - w * 0.4f, cy - h * 0.45f, cx - w * 0.15f, cy - h * 0.45f)
    path.cubicTo(cx, cy - h * 0.45f, cx, cy - h * 0.1f, cx, cy - h * 0.1f)
    path.cubicTo(cx, cy - h * 0.1f, cx, cy - h * 0.45f, cx + w * 0.15f, cy - h * 0.45f)
    path.cubicTo(cx + w * 0.4f, cy - h * 0.45f, cx + w * 0.45f, cy - h * 0.1f, cx, cy + h * 0.35f)
    path.lineTo(cx - w * 0.05f, cy + h * 0.3f)
    return path
  }

  private fun cloudPath(cx: Float, cy: Float, width: Float, height: Float): Path {
    val path = Path()
    path.moveTo(cx - width * 0.4f, cy + height * 0.2f)
    path.lineTo(cx + width * 0.4f, cy + height * 0.2f)
    path.quadTo(cx + width * 0.55f, cy - height * 0.1f, cx + width * 0.35f, cy - height * 0.3f)
    path.quadTo(cx + width * 0.20f, cy - height * 0.6f, cx, cy - height * 0.4f)
    path.quadTo(cx - width * 0.20f, cy - height * 0.6f, cx - width * 0.35f, cy - height * 0.3f)
    path.quadTo(cx - width * 0.55f, cy - height * 0.1f, cx - width * 0.4f, cy + height * 0.2f)
    path.close()
    return path
  }

  private fun drawSketchedHeart(canvas: Canvas, cx: Float, cy: Float, size: Float, alpha: Int, time: Float, index: Int) {
    val w = size
    val h = size * 1.05f
    val pathPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(alpha, 255, 255, 255)
      style = Paint.Style.STROKE
      strokeWidth = size * 0.07f
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
    }
    
    canvas.save()
    val rotation = kotlin.math.sin(time * 0.003f + index) * 12f
    canvas.rotate(rotation.toFloat(), cx, cy)

    // Sketch line 1
    canvas.save()
    canvas.translate(Random.nextFloat() * 1.5f - 0.75f, Random.nextFloat() * 1.5f - 0.75f)
    canvas.drawPath(sketchedHeartPath(cx, cy, w, h), pathPaint)
    canvas.restore()

    // Sketch line 2
    canvas.save()
    canvas.translate(Random.nextFloat() * 1.5f - 0.75f, Random.nextFloat() * 1.5f - 0.75f)
    canvas.rotate(Random.nextFloat() * 2f - 1f, cx, cy)
    canvas.drawPath(sketchedHeartPath(cx, cy, w * 0.98f, h * 0.98f), pathPaint)
    canvas.restore()

    canvas.restore()
  }

  private fun drawSketchedCloud(canvas: Canvas, cx: Float, cy: Float, width: Float, height: Float, alpha: Int, time: Float, index: Int) {
    val pathPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(alpha, 255, 255, 255)
      style = Paint.Style.STROKE
      strokeWidth = width * 0.035f
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
    }
    
    canvas.save()
    val bob = kotlin.math.sin(time * 0.0022f + index) * 6f
    canvas.translate(0f, bob.toFloat())

    // Sketch line 1
    canvas.save()
    canvas.translate(Random.nextFloat() * 2f - 1f, Random.nextFloat() * 2f - 1f)
    canvas.drawPath(cloudPath(cx, cy, width, height), pathPaint)
    canvas.restore()

    // Sketch line 2
    canvas.save()
    canvas.translate(Random.nextFloat() * 2f - 1f, Random.nextFloat() * 2f - 1f)
    canvas.drawPath(cloudPath(cx, cy, width * 0.99f, height * 0.99f), pathPaint)
    canvas.restore()

    canvas.restore()
  }

  fun drawNeonOutline(canvas: Canvas, face: DetectedFace) {
    val box = face.boundingBox
    val faceW = box.width()
    val faceH = box.height()
    val cx = box.centerX()
    val top = topOfHeadPoint(face)
    val foreheadY = (top?.y ?: box.top) + faceH * 0.03f
    val bottom = bottomOfFacePoint(face)
    val bottomFaceY = bottom?.y ?: box.bottom
    val eyeDistance = eyeDistance(face)
    val time = SystemClock.uptimeMillis().toFloat()

    // 1. Draw glowing body/shoulder silhouette outline
    val points = face.faceContour
    val path = Path()
    var hasBodyPath = false

    if (!points.isNullOrEmpty() && points.size >= 36) {
      val leftJaw = points[13]
      val rightJaw = points[23]

      // In mirrored preview, leftJaw is on the right side of the screen (larger X), 
      // so we ADD to leftJaw.x to get the left shoulder.
      // rightJaw is on the left side of the screen (smaller X),
      // so we SUBTRACT from rightJaw.x to get the right shoulder.
      val leftShoulderX = leftJaw.x + faceW * 0.95f
      val leftShoulderY = leftJaw.y + faceH * 0.75f
      val rightShoulderX = rightJaw.x - faceW * 0.95f
      val rightShoulderY = rightJaw.y + faceH * 0.75f

      val bottomY = leftShoulderY + faceH * 3.5f

      // Start at bottom of screen on left side (right of screen in mirrored preview)
      path.moveTo(leftShoulderX, bottomY)
      path.lineTo(leftShoulderX, leftShoulderY)
      path.quadTo(leftJaw.x + faceW * 0.20f, leftJaw.y + faceH * 0.30f, leftJaw.x, leftJaw.y)

      // Trace head outline
      for (i in 13 downTo 0) {
        path.lineTo(points[i].x, points[i].y)
      }
      for (i in 35 downTo 23) {
        path.lineTo(points[i].x, points[i].y)
      }

      // Curve from right jaw to right shoulder
      path.quadTo(rightJaw.x - faceW * 0.20f, rightJaw.y + faceH * 0.30f, rightShoulderX, rightShoulderY)
      path.lineTo(rightShoulderX, bottomY)
      hasBodyPath = true
    }

    val outlinePath = if (hasBodyPath) path else faceOvalPath(face)

    if (outlinePath != null) {
      val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
      }

      // Core white line
      glowPaint.color = Color.WHITE
      glowPaint.strokeWidth = eyeDistance * 0.022f
      canvas.drawPath(outlinePath, glowPaint)

      // Neon outer glows
      glowPaint.color = Color.argb(160, 255, 255, 255)
      glowPaint.strokeWidth = eyeDistance * 0.042f
      canvas.drawPath(outlinePath, glowPaint)

      glowPaint.color = Color.argb(95, 255, 255, 255)
      glowPaint.strokeWidth = eyeDistance * 0.082f
      canvas.drawPath(outlinePath, glowPaint)

      glowPaint.color = Color.argb(40, 255, 255, 255)
      glowPaint.strokeWidth = eyeDistance * 0.132f
      canvas.drawPath(outlinePath, glowPaint)
    }

    // 2. Draw floating sketched hearts
    val heartLocations = listOf(
      Triple(-0.72f, -0.22f, 0.16f), // top-left far
      Triple(-0.45f, -0.42f, 0.14f), // top-left near
      Triple( 0.45f, -0.42f, 0.14f), // top-right near
      Triple( 0.72f, -0.22f, 0.16f), // top-right far
      Triple(-0.85f,  0.15f, 0.15f), // mid-left
      Triple( 0.85f,  0.15f, 0.15f)  // mid-right
    )

    heartLocations.forEachIndexed { index, (rx, ry, sizeMult) ->
      val bobY = kotlin.math.sin(time * 0.0022f + index * 1.5f) * faceH * 0.03f
      val bobX = kotlin.math.cos(time * 0.0018f + index * 0.9f) * faceW * 0.02f
      val hCx = cx + rx * faceW + bobX
      val hCy = foreheadY + ry * faceH + bobY
      val size = faceW * sizeMult

      drawSketchedHeart(canvas, hCx, hCy, size, 220, time, index)
    }

    // 3. Draw sketched clouds at the bottom
    data class CloudLoc(val rx: Float, val ry: Float, val wMult: Float, val hMult: Float)
    val cloudLocations = listOf(
      CloudLoc(-0.48f, 0.22f, 0.35f, 0.18f),
      CloudLoc( 0.48f, 0.22f, 0.35f, 0.18f)
    )

    cloudLocations.forEachIndexed { index, loc ->
      val clX = cx + loc.rx * faceW
      val clY = bottomFaceY + loc.ry * faceH
      val clW = faceW * loc.wMult
      val clH = faceH * loc.hMult
      
      drawSketchedCloud(canvas, clX, clY, clW, clH, 200, time, index)
    }
  }

  fun drawHeartFrame(canvas: Canvas, bitmap: Bitmap, faces: List<DetectedFace>) {
    val w = bitmap.width.toFloat()
    val h = bitmap.height.toFloat()

    // 1. Fill entire canvas with black
    canvas.drawColor(Color.BLACK)

    // 2. Define the centered frame dimensions
    val rectW = w * 0.82f
    val rectH = rectW * 0.58f
    val rectLeft = (w - rectW) / 2f
    val rectTop = (h - rectH) / 2f
    val rect = RectF(rectLeft, rectTop, rectLeft + rectW, rectTop + rectH)
    val cornerRadius = rectH * 0.12f

    // 3. Save canvas and clip to the rounded rectangle
    canvas.save()
    val clipPath = Path().apply {
      addRoundRect(rect, cornerRadius, cornerRadius, Path.Direction.CW)
    }
    canvas.clipPath(clipPath)

    // 4. Draw camera bitmap with beautiful warm tone
    ColorFilters.applyWarmTone(canvas, bitmap)

    canvas.restore()

    // 5. Draw a thin, elegant border around the frame
    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(0x88, 255, 255, 255)
      style = Paint.Style.STROKE
      strokeWidth = w * 0.006f
    }
    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, borderPaint)

    // 6. Draw the pink heart at the top-left corner of the frame
    val heartSize = rectW * 0.18f
    val heartCx = rect.left
    val heartCy = rect.top

    canvas.save()
    canvas.translate(heartCx, heartCy)
    canvas.rotate(-15f)

    // Radial gradient for a beautiful spherical 3D glossy look
    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        -heartSize * 0.15f, -heartSize * 0.15f, heartSize * 0.8f,
        intArrayOf(Color.parseColor("#ff8bb6"), Color.parseColor("#ff2e74"), Color.parseColor("#b3003b")),
        floatArrayOf(0f, 0.6f, 1f),
        Shader.TileMode.CLAMP
      )
      style = Paint.Style.FILL
    }

    val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
    }

    val heartPath = Path().apply {
      val hw = heartSize
      val hh = heartSize * 1.05f
      moveTo(0f, hh * 0.35f)
      cubicTo(-hw * 0.45f, -hh * 0.08f, -hw * 0.40f, -hh * 0.45f, -hw * 0.12f, -hh * 0.45f)
      cubicTo(0f, -hh * 0.45f, 0f, -hh * 0.10f, 0f, -hh * 0.10f)
      cubicTo(0f, -hh * 0.10f, 0f, -hh * 0.45f, hw * 0.12f, -hh * 0.45f)
      cubicTo(hw * 0.40f, -hh * 0.45f, hw * 0.45f, -hh * 0.08f, 0f, hh * 0.35f)
      close()
    }

    // Realistic multi-layered drop shadow to emulate soft blur
    canvas.save()
    for (i in 1..4) {
      val offset = heartSize * 0.02f * i
      val alpha = 0x24 / i
      shadowPaint.color = Color.argb(alpha, 0, 0, 0)
      canvas.save()
      canvas.translate(offset, offset)
      canvas.drawPath(heartPath, shadowPaint)
      canvas.restore()
    }
    canvas.restore()

    // Draw realistic glossy heart body
    canvas.drawPath(heartPath, fillPaint)

    // Primary glossy white highlight reflection
    val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(0xEE, 255, 255, 255)
      style = Paint.Style.FILL
    }
    val hw = heartSize
    val hh = heartSize * 1.05f
    canvas.drawCircle(-hw * 0.15f, -hh * 0.20f, hw * 0.07f, highlightPaint)

    // Secondary soft specular glass reflection highlight
    val softHighlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(0x66, 255, 255, 255)
      style = Paint.Style.FILL
    }
    canvas.drawCircle(-hw * 0.10f, -hh * 0.15f, hw * 0.12f, softHighlightPaint)

    canvas.restore()
  }

  fun drawCityTime(canvas: Canvas, bitmap: Bitmap, faces: List<DetectedFace>) {
    val w = bitmap.width.toFloat()
    val h = bitmap.height.toFloat()

    // 1. Fill entire canvas with black
    canvas.drawColor(Color.BLACK)

    // 2. Define the upper camera feed rectangle
    val rectW = w
    val rectH = w * 1.22f
    val rect = RectF(0f, 0f, rectW, rectH)

    // 3. Save canvas and clip to this top rectangle
    canvas.save()
    canvas.clipRect(rect)

    // 4. Draw camera bitmap with sunset warm grading
    ColorFilters.applySunset(canvas, bitmap)

    canvas.restore()

    // 5. Get current dynamic time formatted as HH:mm
    val timeStr = try {
      java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(java.util.Date())
    } catch (e: Exception) {
      "12:15"
    }
    val fullText = timeStr

    // 6. Draw the golden-orange text stamp on the black background just below the bottom of the camera feed
    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#e09f3e")
      textSize = w * 0.052f
      try {
        typeface = android.graphics.Typeface.create("cursive", android.graphics.Typeface.ITALIC)
      } catch (e: Exception) {
        typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.ITALIC)
      }
    }

    // 7. Save canvas and un-mirror horizontally so text reads normally
    canvas.save()
    if (isFrontCamera) {
      canvas.translate(w, 0f)
      canvas.scale(-1f, 1f)
    }

    val left = w * 0.12f
    val textY = rect.bottom + w * 0.08f
    canvas.drawText(fullText, left, textY, textPaint)

    canvas.restore()
  }

  fun drawPookieBow(canvas: Canvas, face: DetectedFace, bowBitmap: Bitmap) {
    val re = rightEye(face) ?: return
    val le = leftEye(face)  ?: return
    val rollAngle = face.rollAngle

    val eyeMidX = (le.x + re.x) / 2f
    val eyeMidY = (le.y + re.y) / 2f
    val eyeDist = hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    val anchor  = PointF(eyeMidX, eyeMidY)

    // Bow display size: scale so bow width ≈ 1.15 × eye distance
    val bowDisplayW = eyeDist * 1.15f
    val scale       = bowDisplayW / bowBitmap.width.toFloat()
    val bowDisplayH = bowBitmap.height * scale

    // Position: above the face's right eye, shifted a bit to the right and up
    val bx = re.x + eyeDist * 0.15f
    val by = re.y - eyeDist * 0.80f

    val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    withHeadRotation(canvas, anchor, rollAngle) {
      val mat = Matrix()
      mat.postScale(scale, scale)
      mat.postTranslate(bx - bowDisplayW / 2f, by - bowDisplayH / 2f)
      mat.postRotate(35f, bx, by) // tilt towards the right
      canvas.drawBitmap(bowBitmap, mat, bitmapPaint)
    }
  }

  private var processedPandaBitmap: Bitmap? = null

  fun drawPandaFaces(canvas: Canvas, face: DetectedFace, rawPandaBitmap: Bitmap) {
    val panda = processedPandaBitmap ?: run {
      val width = rawPandaBitmap.width
      val height = rawPandaBitmap.height
      val pixels = IntArray(width * height)
      rawPandaBitmap.getPixels(pixels, 0, width, 0, 0, width, height)

      // Chroma keying: Convert magenta pixels (R and B high, G low) to transparent, keeping whites white
      for (i in pixels.indices) {
        val color = pixels[i]
        val r = (color shr 16) and 0xFF
        val g = (color shr 8) and 0xFF
        val b = color and 0xFF
        if (r > 180 && b > 180 && g < 120) {
          pixels[i] = 0x00000000
        }
      }
      val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      out.setPixels(pixels, 0, width, 0, 0, width, height)
      processedPandaBitmap = out
      out
    }

    val box = face.boundingBox
    val faceW = box.width()
    val faceH = box.height()
    val cx = box.centerX()
    val cy = box.centerY()

    val rollAngle = face.rollAngle
    val anchor = PointF(cx, cy)

    class PandaStamp(val rx: Float, val ry: Float, val sm: Float, val rot: Float)

    // Adjust offsets to be a little bit wider (halfway between original and narrowed)
    val stamps = listOf(
      PandaStamp(-0.21f, -0.32f, 0.70f, -12f),  // forehead left
      PandaStamp(0.21f, -0.32f, 0.70f, 15f),    // forehead right
      PandaStamp(-0.33f, -0.15f, 0.65f, -20f),  // temple left
      PandaStamp(0.33f, -0.15f, 0.65f, 25f),   // temple right
      PandaStamp(-0.13f, 0.05f, 0.60f, -5f),    // near nose bridge left
      PandaStamp(0.13f, 0.05f, 0.60f, 8f),     // near nose bridge right
      PandaStamp(-0.30f, 0.15f, 0.75f, -15f),   // upper cheek left
      PandaStamp(0.30f, 0.15f, 0.75f, 12f),    // upper cheek right
      PandaStamp(-0.21f, 0.32f, 0.68f, -8f),    // lower cheek left
      PandaStamp(0.21f, 0.32f, 0.68f, 18f),     // lower cheek right
      PandaStamp(0.00f, 0.46f, 0.72f, 0f),      // chin
      PandaStamp(-0.11f, 0.25f, 0.55f, -10f),   // under lips left
      PandaStamp(0.11f, 0.25f, 0.55f, 12f)      // under lips right
    )

    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    withHeadRotation(canvas, anchor, rollAngle) {
      val mat = Matrix()
      for (stamp in stamps) {
        val px = cx + stamp.rx * faceW
        val py = cy + stamp.ry * faceH

        // Scale pandas to be slightly smaller and fit perfectly within face boundaries
        val targetSize = faceW * 0.12f * stamp.sm
        val scale = targetSize / panda.width.toFloat()

        mat.reset()
        mat.postScale(scale, scale)
        mat.postTranslate(px - targetSize / 2f, py - targetSize / 2f)
        mat.postRotate(stamp.rot, px, py)

        canvas.drawBitmap(panda, mat, paint)
      }
    }
  }

  fun drawSpidermanMask(canvas: Canvas, face: DetectedFace) {
    val facePoints = face.faceContour
    if (facePoints.isNullOrEmpty()) return
    val b = face.boundingBox
    val faceW = b.width()
    val faceH = b.height()
    val cx = b.centerX()
    val cy = b.centerY()
    val le = leftEye(face) ?: return
    val re = rightEye(face) ?: return
    val eyeDist = eyeDistance(face)
    if (eyeDist == 0f) return

    val rollAngle = face.rollAngle
    val anchor = PointF(cx, cy)

    // Calculate local eye coordinates in the rotated canvas space
    val localLe = getLocalPoint(le, anchor, rollAngle)
    val lx = localLe.x - anchor.x
    val ly = localLe.y - anchor.y

    val localRe = getLocalPoint(re, anchor, rollAngle)
    val rx = localRe.x - anchor.x
    val ry = localRe.y - anchor.y

    // Center of the spider web is at the nose bridge (midpoint between eyes, shifted down slightly)
    val webCx = (lx + rx) / 2f
    val webCy = (ly + ry) / 2f + eyeDist * 0.12f

    // 1. Build custom path stretching the forehead/head top points slightly upwards and outwards
    val maskPath = Path()
    val firstPt = facePoints[0]
    val firstX = if (firstPt.y < cy) cx + (firstPt.x - cx) * 1.05f else firstPt.x
    val firstY = if (firstPt.y < cy) cy - (cy - firstPt.y) * 1.15f else firstPt.y
    maskPath.moveTo(firstX, firstY)

    for (i in 1 until facePoints.size) {
      val pt = facePoints[i]
      val px = if (pt.y < cy) cx + (pt.x - cx) * 1.05f else pt.x
      val py = if (pt.y < cy) cy - (cy - pt.y) * 1.15f else pt.y
      maskPath.lineTo(px, py)
    }
    maskPath.close()

    canvas.save()
    // 2. Clip to the face contour in screen space
    canvas.clipPath(maskPath)

    // 2. Translate and rotate to align with head rotation
    canvas.translate(anchor.x, anchor.y)
    canvas.rotate(-rollAngle)

    // 3. Draw black base mask filling the face
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.BLACK
      style = Paint.Style.FILL
    }
    canvas.drawRect(RectF(-faceW * 1.5f, -faceH * 1.5f, faceW * 1.5f, faceH * 1.5f), paint)

    // 4. Draw white web pattern
    val webPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = faceW * 0.010f
    }

    val numRadials = 12
    val maxRadius = max(faceW, faceH) * 1.5f

    // Draw radial web lines
    for (i in 0 until numRadials) {
      val angle = (2 * Math.PI * i / numRadials).toFloat()
      canvas.drawLine(webCx, webCy, webCx + cos(angle) * maxRadius, webCy + sin(angle) * maxRadius, webPaint)
    }

    // Draw sagging concentric web rings
    val numRings = 6
    for (r in 1..numRings) {
      val radius = maxRadius * 0.14f * r
      val webPath = Path()
      for (i in 0..numRadials) {
        val angle1 = (2 * Math.PI * i / numRadials).toFloat()
        val x1 = webCx + cos(angle1) * radius
        val y1 = webCy + sin(angle1) * radius

        if (i == 0) {
          webPath.moveTo(x1, y1)
        } else {
          val anglePrev = (2 * Math.PI * (i - 1) / numRadials).toFloat()
          val angleMid = (anglePrev + angle1) / 2f
          val ctrlRadius = radius * 0.86f
          val cx1 = webCx + cos(angleMid) * ctrlRadius
          val cy1 = webCy + sin(angleMid) * ctrlRadius
          webPath.quadTo(cx1, cy1, x1, y1)
        }
      }
      canvas.drawPath(webPath, webPaint)
    }

    // 5. Draw Spider-Man slanted eyes
    val leftEyePath = Path().apply {
      moveTo(lx + eyeDist * 0.32f, ly + eyeDist * 0.10f)
      quadTo(
        lx - 0.05f * eyeDist, ly - 0.25f * eyeDist,
        lx - 0.40f * eyeDist, ly - 0.30f * eyeDist
      )
      quadTo(
        lx - 0.48f * eyeDist, ly - 0.05f * eyeDist,
        lx - 0.45f * eyeDist, ly + 0.15f * eyeDist
      )
      quadTo(
        lx - 0.10f * eyeDist, ly + 0.28f * eyeDist,
        lx + 0.32f * eyeDist, ly + 0.10f * eyeDist
      )
      close()
    }

    val rightEyePath = Path().apply {
      moveTo(rx - eyeDist * 0.32f, ry + eyeDist * 0.10f)
      quadTo(
        rx + 0.05f * eyeDist, ry - 0.25f * eyeDist,
        rx + 0.40f * eyeDist, ry - 0.30f * eyeDist
      )
      quadTo(
        rx + 0.48f * eyeDist, ry - 0.05f * eyeDist,
        rx + 0.45f * eyeDist, ry + 0.15f * eyeDist
      )
      quadTo(
        rx + 0.10f * eyeDist, ry + 0.28f * eyeDist,
        rx - 0.32f * eyeDist, ry + 0.10f * eyeDist
      )
      close()
    }

    val eyeFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.FILL
    }
    canvas.drawPath(leftEyePath, eyeFillPaint)
    canvas.drawPath(rightEyePath, eyeFillPaint)

    val eyeBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.BLACK
      style = Paint.Style.STROKE
      strokeWidth = eyeDist * 0.14f
      strokeJoin = Paint.Join.ROUND
      strokeCap = Paint.Cap.ROUND
    }
    canvas.drawPath(leftEyePath, eyeBorderPaint)
    canvas.drawPath(rightEyePath, eyeBorderPaint)

    canvas.restore()
  }

  private fun getTornOffset(x: Float, frequencyScale: Float): Float {
    return (
      sin(x * 0.04f * frequencyScale) * 8f +
      cos(x * 0.095f * frequencyScale) * 5f +
      sin(x * 0.22f * frequencyScale) * 2.5f
    )
  }

  fun drawEyesReveal(canvas: Canvas, frame: Bitmap, face: DetectedFace?) {
    // 1. Fill entire canvas with solid black
    canvas.drawColor(Color.BLACK)

    val canvasW = frame.width.toFloat()
    val canvasH = frame.height.toFloat()

    // Fixed position and dimensions for the torn paper strip
    val cx = canvasW * 0.5f
    val cy = canvasH * 0.42f
    val halfW = canvasW * 0.46f
    val halfH = canvasH * 0.082f
    val rollAngle = 0f

    // 2. Build local torn path
    val localTornPath = Path()
    val steps = 80
    val stepSize = (halfW * 2f) / steps

    val startX = -halfW
    val startY = -halfH + getTornOffset(startX, 1f)
    localTornPath.moveTo(startX, startY)

    for (i in 1..steps) {
      val x = -halfW + i * stepSize
      val y = -halfH + getTornOffset(x, 1f)
      localTornPath.lineTo(x, y)
    }

    val endBotY = halfH + getTornOffset(halfW, 1.2f)
    localTornPath.lineTo(halfW, endBotY)

    for (i in steps - 1 downTo 0) {
      val x = -halfW + i * stepSize
      val y = halfH + getTornOffset(x, 1.2f)
      localTornPath.lineTo(x, y)
    }
    localTornPath.close()

    // 3. Transform to screen space
    val matrix = Matrix().apply {
      postRotate(-rollAngle)
      postTranslate(cx, cy)
    }
    val screenTornPath = Path()
    localTornPath.transform(matrix, screenTornPath)

    // 4. Clip to path and draw camera frame in high-contrast grayscale
    canvas.save()
    canvas.clipPath(screenTornPath)

    val grayscalePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      val cm = android.graphics.ColorMatrix().apply {
        setSaturation(0f)
        val scale = 1.35f
        val translate = -30f
        val contrastMatrix = floatArrayOf(
          scale, 0f, 0f, 0f, translate,
          0f, scale, 0f, 0f, translate,
          0f, 0f, scale, 0f, translate,
          0f, 0f, 0f, 1f, 0f
        )
        postConcat(android.graphics.ColorMatrix(contrastMatrix))
      }
      colorFilter = android.graphics.ColorMatrixColorFilter(cm)
    }

    canvas.drawBitmap(frame, 0f, 0f, grayscalePaint)
    canvas.restore()

    // 5. Draw white border around the torn path
    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = canvasW * 0.012f
      strokeJoin = Paint.Join.ROUND
      strokeCap = Paint.Cap.ROUND
    }
    canvas.drawPath(screenTornPath, borderPaint)

    // 6. Draw centered white text "eyes always reveal the truth 👀✨"
    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      textSize = canvasW * 0.046f
      textAlign = Paint.Align.CENTER
      typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD_ITALIC)
    }

    val textY = canvasH * 0.58f
    
    // Save, translate to text position, scale by -1 to flip mirrored text back to normal, and draw
    canvas.save()
    canvas.translate(canvasW * 0.5f, textY)
    if (isFrontCamera) {
      canvas.scale(-1f, 1f)
    }
    canvas.drawText("eyes always reveal the truth 👀✨", 0f, 0f, textPaint)
    canvas.restore()
  }

  fun drawWantedPoster(canvas: Canvas, bitmap: Bitmap) {
    val w = bitmap.width.toFloat()
    val h = bitmap.height.toFloat()

    // 1. Draw Brick Wall Background
    val brickColors = intArrayOf(
      Color.parseColor("#7a2414"), // dark red-brown
      Color.parseColor("#691f11"), // deeper red-brown
      Color.parseColor("#8a3523"), // terracotta
      Color.parseColor("#571a0e"), // very dark brick
      Color.parseColor("#9c4430")  // warm red
    )

    val rowH = h / 16f
    val brickW = w / 3.5f
    val brickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
    }
    val mortarPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#bfb2a3") // mortar grey-cream
      style = Paint.Style.STROKE
      strokeWidth = w * 0.008f
    }

    for (row in 0 until 17) {
      val top = row * rowH
      val bottom = top + rowH
      val offset = if (row % 2 == 0) 0f else -brickW / 2f
      
      var left = offset
      while (left < w + brickW) {
        val right = left + brickW
        
        // Stable color seed based on position
        val seed = (row * 37 + (left / brickW).toInt() * 17)
        val index = Math.abs(seed) % brickColors.size
        brickPaint.color = brickColors[index]

        val rect = RectF(left, top, right, bottom)
        canvas.drawRect(rect, brickPaint)
        canvas.drawRect(rect, mortarPaint)
        
        left += brickW
      }
    }

    // 2. Draw Wanted Poster Parchment Paper
    val posterW = w * 0.84f
    val posterH = posterW * 1.45f
    val posterLeft = (w - posterW) / 2f
    val posterTop = (h - posterH) / 2f
    val posterRect = RectF(posterLeft, posterTop, posterLeft + posterW, posterTop + posterH)

    val paperPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#eedab3") // vintage aged parchment
    }
    canvas.drawRect(posterRect, paperPaint)

    // Aged vignette style shadow around parchment corners
    val vignettePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        w / 2f, h / 2f, posterH * 0.7f,
        intArrayOf(Color.TRANSPARENT, Color.argb(0x1a, 0, 0, 0), Color.argb(0x55, 100, 60, 20)),
        floatArrayOf(0f, 0.7f, 1f),
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawRect(posterRect, vignettePaint)

    // Inner poster borders (classic wanted poster thin black border)
    val borderOffset = posterW * 0.024f
    val innerBorder = RectF(
      posterLeft + borderOffset,
      posterTop + borderOffset,
      posterLeft + posterW - borderOffset,
      posterTop + posterH - borderOffset
    )
    val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#2b221a") // dark brown/black
      style = Paint.Style.STROKE
      strokeWidth = posterW * 0.008f
    }
    canvas.drawRect(innerBorder, linePaint)

    // 3. Draw Cutout Frame (where camera feed goes)
    val frameW = posterW * 0.82f
    val frameH = frameW * 0.96f
    val frameLeft = posterLeft + (posterW - frameW) / 2f
    val frameTop = posterTop + posterH * 0.215f
    val frameRect = RectF(frameLeft, frameTop, frameLeft + frameW, frameTop + frameH)

    canvas.save()
    canvas.clipRect(frameRect)
    
    // Draw camera bitmap with vintage filter
    val sepiaPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    sepiaPaint.colorFilter = android.graphics.ColorMatrixColorFilter(ColorMatrices.VINTAGE)
    canvas.drawBitmap(bitmap, 0f, 0f, sepiaPaint)
    
    canvas.restore()

    // Draw frame border
    val frameBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#2b221a")
      style = Paint.Style.STROKE
      strokeWidth = posterW * 0.016f
    }
    canvas.drawRect(frameRect, frameBorderPaint)

    // 4. Texts
    val cx = w / 2f

    val wantedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#1c140e")
      textSize = posterW * 0.15f
      typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
      letterSpacing = 0.06f
    }

    val deadOrAlivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#1c140e")
      textSize = posterW * 0.062f
      typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
      letterSpacing = 0.02f
    }

    val rewardPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#1c140e")
      textSize = posterW * 0.062f
      typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }

    val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#1c140e")
      textSize = posterW * 0.055f
      typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }

    fun drawFlippedText(text: String, x: Float, y: Float, paint: Paint) {
      canvas.save()
      canvas.translate(x, y)
      if (isFrontCamera) {
        canvas.scale(-1f, 1f)
      }
      canvas.drawText(text, 0f, 0f, paint)
      canvas.restore()
    }

    drawFlippedText("WANTED", cx, posterTop + posterH * 0.125f, wantedPaint)
    drawFlippedText("★ DEAD OR ALIVE ★", cx, posterTop + posterH * 0.185f, deadOrAlivePaint)
    drawFlippedText("$1,000,000 REWARD", cx, posterTop + posterH * 0.865f, rewardPaint)
    drawFlippedText("DANGEROUSLY CUTE", cx, posterTop + posterH * 0.93f, subTextPaint)
  }

  fun drawPlumeriaFlower(canvas: Canvas, face: DetectedFace) {
    val re = rightEye(face) ?: return
    val le = leftEye(face) ?: return
    
    val eyeDistance = kotlin.math.hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    
    // Position on top of the right ear if it is detected; otherwise fallback to the calculated eye-relative offset
    val earPoint = rightEar(face)
    val earX: Float
    val earY: Float
    if (earPoint != null) {
      // Ear landmark detected! Position higher above the ear midpoint and push slightly outward
      earX = earPoint.x - eyeDistance * 0.05f
      earY = earPoint.y - eyeDistance * 0.42f
    } else {
      // Fallback relative to the right eye (lifted higher and pushed further to the right)
      earX = re.x + eyeDistance * 0.48f
      earY = re.y - eyeDistance * 0.42f
    }
    
    val size = eyeDistance * 0.45f
    val rollAngle = face.rollAngle
    
    canvas.save()
    canvas.translate(earX, earY)
    canvas.rotate(-rollAngle)
    
    // Draw subtle drop shadow first (offset down-right slightly)
    val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.argb(0x2d, 0, 0, 0)
      style = Paint.Style.FILL
    }
    
    val petalPath = Path().apply {
      moveTo(0f, 0f)
      cubicTo(-size * 0.35f, -size * 0.4f, -size * 0.25f, -size, 0f, -size)
      cubicTo(size * 0.25f, -size, size * 0.35f, -size * 0.4f, 0f, 0f)
      close()
    }
    
    // Draw shadow petals
    canvas.save()
    canvas.translate(size * 0.08f, size * 0.08f)
    for (i in 0 until 5) {
      canvas.drawPath(petalPath, shadowPaint)
      canvas.rotate(72f)
    }
    canvas.restore()
    
    // Curated gradient colors for plumeria petal (yellow center -> white -> vibrant pink edge)
    val petalColors = intArrayOf(
      Color.parseColor("#ffcc00"), // Yellow center
      Color.parseColor("#fffbeb"), // Cream transition
      Color.parseColor("#ffffff"), // Pure white body
      Color.parseColor("#ffa6c9"), // Soft pink
      Color.parseColor("#ff4da6")  // Rich pink edge
    )
    val colorPositions = floatArrayOf(0f, 0.2f, 0.5f, 0.85f, 1f)
    
    val petalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
    }
    
    // Draw the 5 petals of the plumeria flower
    for (i in 0 until 5) {
      petalPaint.shader = LinearGradient(
        0f, 0f, 0f, -size,
        petalColors, colorPositions,
        Shader.TileMode.CLAMP
      )
      canvas.drawPath(petalPath, petalPaint)
      canvas.rotate(72f)
    }
    
    // Draw a small bright yellow center stamen glow
    val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        0f, 0f, size * 0.22f,
        intArrayOf(Color.parseColor("#ffa600"), Color.parseColor("#ffcc00"), Color.TRANSPARENT),
        floatArrayOf(0.0f, 0.5f, 1f),
        Shader.TileMode.CLAMP
      )
      style = Paint.Style.FILL
    }
    canvas.drawCircle(0f, 0f, size * 0.22f, centerPaint)
    
    canvas.restore()
  }

  fun drawSkullFixed(canvas: Canvas, frame: Bitmap, skullBitmap: Bitmap) {
    val w = frame.width.toFloat()
    val h = frame.height.toFloat()
    
    val cx = w * 0.5f
    val cy = h * 0.64f
    
    val skullW = w * 0.20f
    val skullH = skullW * (skullBitmap.height.toFloat() / skullBitmap.width.toFloat())
    
    canvas.save()
    canvas.translate(cx, cy)
    
    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    val rect = RectF(-skullW * 0.5f, -skullH * 0.5f, skullW * 0.5f, skullH * 0.5f)
    canvas.drawBitmap(skullBitmap, null, rect, paint)
    
    canvas.restore()
  }

  fun drawTalkingForest(canvas: Canvas, frame: Bitmap, face: DetectedFace?, bgBitmap: Bitmap) {
    val canvasW = frame.width.toFloat()
    val canvasH = frame.height.toFloat()

    // 1. Draw static background forest image first (center-crop cover)
    val bgW = bgBitmap.width.toFloat()
    val bgH = bgBitmap.height.toFloat()
    val bgScale = maxOf(canvasW / bgW, canvasH / bgH)
    val bgSrcW = canvasW / bgScale
    val bgSrcH = canvasH / bgScale
    val bgSrcX = (bgW - bgSrcW) / 2f
    val bgSrcY = (bgH - bgSrcH) / 2f
    val bgSrcRect = Rect(bgSrcX.toInt(), bgSrcY.toInt(), (bgSrcX + bgSrcW).toInt(), (bgSrcY + bgSrcH).toInt())
    val destRect = RectF(0f, 0f, canvasW, canvasH)
    canvas.drawBitmap(bgBitmap, bgSrcRect, destRect, null)

    // If there is no face detected, we only draw the background
    val f = face ?: return

    val le = leftEye(f)
    val re = rightEye(f)
    val upper = f.upperLip
    val lower = f.lowerLip

    if (le == null || re == null || upper.isNullOrEmpty() || lower.isNullOrEmpty()) return

    // Calculate eye distance for sizing the crops
    val eyeDist = kotlin.math.hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
    if (eyeDist <= 0f) return

    // Calculate mouth/lips center
    val allLipsPoints = upper + lower
    val mcX = allLipsPoints.map { it.x }.average().toFloat()
    val mcY = allLipsPoints.map { it.y }.average().toFloat()

    // Draw feathered left eye
    drawFeatheredCrop(canvas, frame, le.x, le.y, eyeDist * 0.40f, eyeDist * 0.28f)

    // Draw feathered right eye
    drawFeatheredCrop(canvas, frame, re.x, re.y, eyeDist * 0.40f, eyeDist * 0.28f)

    // Draw feathered mouth/lips
    drawFeatheredCrop(canvas, frame, mcX, mcY, eyeDist * 0.65f, eyeDist * 0.40f)
  }

  private fun drawFeatheredCrop(
    canvas: Canvas,
    srcBitmap: Bitmap,
    cx: Float,
    cy: Float,
    rx: Float,
    ry: Float
  ) {
    val rect = RectF(cx - rx, cy - ry, cx + rx, cy + ry)
    
    // Save layer to isolate alpha-blending
    val saveCount = canvas.saveLayer(rect, null)
    
    // 1. Draw the oval gradient mask first
    val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        cx, cy, maxOf(rx, ry),
        intArrayOf(Color.WHITE, Color.WHITE, Color.TRANSPARENT),
        floatArrayOf(0f, 0.4f, 1f),
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawOval(rect, maskPaint)
    
    // 2. Draw the bitmap on top with SRC_IN xfermode
    val srcL = (cx - rx).toInt().coerceIn(0, srcBitmap.width)
    val srcT = (cy - ry).toInt().coerceIn(0, srcBitmap.height)
    val srcR = (cx + rx).toInt().coerceIn(0, srcBitmap.width)
    val srcB = (cy + ry).toInt().coerceIn(0, srcBitmap.height)
    val srcRect = Rect(srcL, srcT, srcR, srcB)
    
    // Destination rect is mapped proportionally to avoid stretching/squeezing
    val destRect = RectF(cx - (cx - srcL), cy - (cy - srcT), cx + (srcR - cx), cy + (srcB - cy))
    
    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
      xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
    }
    canvas.drawBitmap(srcBitmap, srcRect, destRect, paint)
    
    canvas.restoreToCount(saveCount)
  }

  // Identity card data state
  private var cardName = "Raksha \uD83C\uDF08"
  private var cardUserId = "RAK_SHA80"
  private var cardDepartment = "printing engineer"
  private var cardRole = "Midnight Scroller ★★★"
  private var cardHobby = "Opening Snapchat 94x/Day"
  private var cardAttentionRate = "5.1 sec"
  private var cardSleepHours = "5.3"
  private var cardDeluluLevel = "97%"

  // EMA smoothing float states
  private var currentDeluluVal = 97f
  private var currentSleepHoursVal = 5.3f
  private var currentAttentionRateVal = 5.1f

  // Personality modifier offsets (randomized on screen tap)
  private var deluluModifier = 0f
  private var sleepModifier = 0f
  private var attentionModifier = 0f

  // Creator HUD view count state
  private var creatorViewerCount = "1.2TCR"
  private val viewerCounts = listOf("1.2TCR", "2.8TCR", "5.4CR", "8.9CR", "10.5B", "3.2M", "1.2B", "9.7CR", "15.4TCR", "99.9K")

  fun randomizeCreatorHud() {
    val random = Random.Default
    creatorViewerCount = viewerCounts[random.nextInt(viewerCounts.size)]
  }

  private val names = listOf("Raksha \uD83C\uDF08", "Abhay \uD83D\uDE80", "Ananya ✨", "Vikram \uD83E\uDD81", "Neha \uD83C\uDF38", "Rahul \uD83C\uDFA7", "Sneha \uD83E\uDD84", "Ishaan \uD83C\uDF55", "Priya \uD83C\uDF6D", "Kabir \uD83C\uDFB8", "Karan \uD83E\uDD81", "Tanya \uD83E\uDD8B", "Udesh \uD83D\uDCF1", "Shreya \uD83C\uDFA8")
  private val userIds = listOf("RAK_SHA80", "ABHAY_99", "ANANYA_X", "VIK_RAM", "NEHA_VIBES", "RAHUL_Z", "SNEHA_BFF", "ISHAAN_FOOD", "PRIYA_CHIC", "KABIR_ROCK", "UDESH_CODER")
  private val departments = listOf("printing engineer", "sleeping expert", "delulu scientist", "coffee consumer", "meme creator", "bug creator", "vibe inspector", "midnight scroller", "reels therapist", "snack tester")
  private val roles = listOf("Midnight Scroller ★★★", "Certified Yapper ★★★", "Professional Overthinker ★★★", "Procrastinator Pro ★★★", "Meme Lord ★★★", "Code Breaker ★★★", "Drama Critic ★★★", "Nap Enthusiast ★★★")
  private val hobbies = listOf("Opening Snapchat 94x/Day", "Staring at ceiling", "Creating fake scenarios", "Drinking iced coffee", "Ignoring red flags", "Scrolling until 4 AM", "Buying stuff online", "Talking to pets")

  fun randomizeLensVerifiedCard() {
    val random = Random.Default
    cardName = names[random.nextInt(names.size)]
    val baseName = cardName.split(" ").firstOrNull()?.uppercase() ?: "USER"
    cardUserId = "${baseName}_${random.nextInt(10, 99)}"
    cardDepartment = departments[random.nextInt(departments.size)]
    cardRole = roles[random.nextInt(roles.size)]
    cardHobby = hobbies[random.nextInt(hobbies.size)]
    
    // Randomize offsets to act as baseline modifiers
    deluluModifier = (random.nextFloat() - 0.5f) * 30f // -15% to +15% delulu base
    sleepModifier = (random.nextFloat() - 0.5f) * 4f // -2 to +2 hours base
    attentionModifier = (random.nextFloat() - 0.5f) * 3f // -1.5 to +1.5 sec base
  }

  private fun drawFlippedText(canvas: Canvas, text: String, x: Float, y: Float, paint: Paint) {
    canvas.save()
    canvas.translate(x, y)
    if (isFrontCamera) {
      canvas.scale(-1f, 1f)
    }
    canvas.drawText(text, 0f, 0f, paint)
    canvas.restore()
  }

  fun drawLensVerifiedCard(canvas: Canvas, bitmap: Bitmap, face: DetectedFace?) {
    // 1. Dynamically compute targets based on detected face features
    if (face != null) {
      val s = face.smilingProbability ?: 0.5f
      val l = face.leftEyeOpenProbability ?: 0.9f
      val r = face.rightEyeOpenProbability ?: 0.9f
      val eyeOpen = (l + r) / 2f
      val pitch = face.pitchAngle
      val yaw = face.yawAngle
      val roll = face.rollAngle

      val targetDelulu = (50f + s * 40f + (kotlin.math.abs(roll).coerceAtMost(30f) / 30f) * 10f + deluluModifier).coerceIn(1f, 100f)
      val sleepReduction = if (pitch < -4f) (kotlin.math.abs(pitch + 4f).coerceAtMost(10f) / 10f) * 2.5f else 0f
      val targetSleep = (3.0f + eyeOpen * 4.5f - sleepReduction + sleepModifier).coerceIn(1.0f, 12.0f)
      val yawReduction = (kotlin.math.abs(yaw).coerceAtMost(25f) / 25f) * 4.0f
      val targetAttention = (1.0f + eyeOpen * 8.0f - yawReduction + attentionModifier).coerceIn(0.1f, 15.0f)

      // Smooth with EMA to eliminate jitter
      currentDeluluVal = currentDeluluVal * 0.85f + targetDelulu * 0.15f
      currentSleepHoursVal = currentSleepHoursVal * 0.85f + targetSleep * 0.15f
      currentAttentionRateVal = currentAttentionRateVal * 0.85f + targetAttention * 0.15f
    } else {
      // Slowly decay back to baseline averages if no face is detected
      currentDeluluVal = currentDeluluVal * 0.95f + (97f + deluluModifier).coerceIn(1f, 100f) * 0.05f
      currentSleepHoursVal = currentSleepHoursVal * 0.95f + (5.3f + sleepModifier).coerceIn(1.0f, 12.0f) * 0.05f
      currentAttentionRateVal = currentAttentionRateVal * 0.95f + (5.1f + attentionModifier).coerceIn(0.1f, 15.0f) * 0.05f
    }

    cardDeluluLevel = "${currentDeluluVal.toInt()}%"
    cardSleepHours = String.format(java.util.Locale.US, "%.1f", currentSleepHoursVal)
    cardAttentionRate = String.format(java.util.Locale.US, "%.1f sec", currentAttentionRateVal)

    val w = bitmap.width.toFloat()
    val h = bitmap.height.toFloat()

    // Card dimensions (Landscape orientation card)
    val cardW = w * 0.94f
    val cardH = cardW * 0.72f
    val cardLeft = (w - cardW) / 2f
    val cardTop = h * 0.15f
    val cardRight = cardLeft + cardW
    val cardBottom = cardTop + cardH
    val cardRect = RectF(cardLeft, cardTop, cardRight, cardBottom)
    val cardRx = cardW * 0.05f

    // 1. Holographic card background gradient: light lavender -> light blue -> light pink -> white
    val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
      shader = LinearGradient(
        cardLeft, cardTop, cardRight, cardBottom,
        intArrayOf(
          Color.parseColor("#EAE9F8"), // light lavender-blue
          Color.parseColor("#EAF3FD"), // light blue
          Color.parseColor("#FBEBF3"), // light pink/rose
          Color.parseColor("#F5F6FC")  // soft white-blue
        ),
        floatArrayOf(0f, 0.35f, 0.7f, 1f),
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawRoundRect(cardRect, cardRx, cardRx, bgPaint)

    // Glassmorphic specular gloss overlay
    val glossPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
      shader = LinearGradient(
        cardLeft, cardTop, cardLeft + cardW * 0.3f, cardTop + cardH * 0.3f,
        intArrayOf(
          Color.argb(0x88, 255, 255, 255),
          Color.argb(0x22, 255, 255, 255),
          Color.TRANSPARENT
        ),
        floatArrayOf(0f, 0.5f, 1f),
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawRoundRect(cardRect, cardRx, cardRx, glossPaint)

    // 2. Watermark concentric circles on the right side of the card
    val wmCx = cardRight - cardW * 0.22f
    val wmCy = cardTop + cardH * 0.46f

    val watermarkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      color = Color.parseColor("#7A8CD0")
      alpha = 25
      strokeWidth = cardW * 0.002f
    }
    for (i in 1..8) {
      canvas.drawCircle(wmCx, wmCy, cardW * 0.03f * i, watermarkPaint)
    }

    // Watermark Shield
    val shieldW = cardW * 0.18f
    val shieldH = shieldW * 1.2f
    val shieldPath = Path().apply {
      moveTo(wmCx, wmCy - shieldH / 2f)
      cubicTo(wmCx + shieldW / 3f, wmCy - shieldH / 2f, wmCx + shieldW / 2f, wmCy - shieldH / 4f, wmCx + shieldW / 2f, wmCy)
      cubicTo(wmCx + shieldW / 2f, wmCy + shieldH / 3f, wmCx + shieldW / 4f, wmCy + shieldH / 2f, wmCx, wmCy + shieldH / 2f)
      cubicTo(wmCx - shieldW / 4f, wmCy + shieldH / 2f, wmCx - shieldW / 2f, wmCy + shieldH / 3f, wmCx - shieldW / 2f, wmCy)
      cubicTo(wmCx - shieldW / 2f, wmCy - shieldH / 4f, wmCx - shieldW / 3f, wmCy - shieldH / 2f, wmCx, wmCy - shieldH / 2f)
      close()
    }
    canvas.drawPath(shieldPath, watermarkPaint)

    val wmTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#7A8CD0")
      alpha = 35
      textSize = cardW * 0.05f
      typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }
    drawFlippedText(canvas, "L+", wmCx, wmCy + cardW * 0.015f, wmTextPaint)

    // Holographic gradient card border
    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeWidth = cardW * 0.008f
      shader = LinearGradient(
        cardLeft, cardTop, cardRight, cardBottom,
        intArrayOf(
          Color.parseColor("#C1C8F6"), // light purple
          Color.parseColor("#8CD7F7"), // light cyan
          Color.parseColor("#F7CCE4"), // light pink
          Color.parseColor("#8CD7F7"), // light cyan
          Color.parseColor("#C1C8F6")  // light purple
        ),
        null,
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawRoundRect(cardRect, cardRx, cardRx, borderPaint)

    // 3. Top Banner
    val headerCx = w / 2f
    val headerPaint1 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#0A3F9A")
      textSize = cardW * 0.052f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }
    drawFlippedText(canvas, "LENS+ VERIFIED", headerCx, cardTop + cardH * 0.12f, headerPaint1)

    val headerPaint2 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5A6B8C")
      textSize = cardW * 0.024f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
      letterSpacing = 0.06f
    }
    drawFlippedText(canvas, "USER IDENTITY CARD", headerCx, cardTop + cardH * 0.17f, headerPaint2)

    // Top Left Icon Box
    val iconBoxL = cardLeft + cardW * 0.04f
    val iconBoxT = cardTop + cardH * 0.06f
    val iconBoxSize = cardW * 0.09f
    val iconBoxR = RectF(iconBoxL, iconBoxT, iconBoxL + iconBoxSize, iconBoxT + iconBoxSize)
    val iconBoxPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#7A8CD0")
      alpha = 40
      style = Paint.Style.FILL
    }
    canvas.drawRoundRect(iconBoxR, iconBoxSize * 0.2f, iconBoxSize * 0.2f, iconBoxPaint)

    val iconBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#7A8CD0")
      style = Paint.Style.STROKE
      strokeWidth = cardW * 0.003f
    }
    canvas.drawRoundRect(iconBoxR, iconBoxSize * 0.2f, iconBoxSize * 0.2f, iconBorderPaint)

    // Crown inside Left Box
    val crownCx = iconBoxL + iconBoxSize / 2f
    val crownCy = iconBoxT + iconBoxSize * 0.55f
    val crownW = iconBoxSize * 0.6f
    val crownH = iconBoxSize * 0.4f
    val crownPath = Path().apply {
      moveTo(crownCx - crownW / 2f, crownCy + crownH / 2f)
      lineTo(crownCx - crownW / 2f, crownCy - crownH * 0.2f)
      lineTo(crownCx - crownW * 0.25f, crownCy + crownH * 0.1f)
      lineTo(crownCx, crownCy - crownH / 2f)
      lineTo(crownCx + crownW * 0.25f, crownCy + crownH * 0.1f)
      lineTo(crownCx + crownW / 2f, crownCy - crownH * 0.2f)
      lineTo(crownCx + crownW / 2f, crownCy + crownH / 2f)
      close()
    }
    val crownPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5C6BC0")
      style = Paint.Style.FILL
    }
    canvas.drawPath(crownPath, crownPaint)

    // 8.9CR below crown
    val label89crPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#0A3F9A")
      textSize = cardW * 0.024f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }
    drawFlippedText(canvas, "8.9CR", crownCx, iconBoxT + iconBoxSize + cardW * 0.028f, label89crPaint)

    // Top Right Level info
    val trX = cardRight - cardW * 0.04f
    val idLevelLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5A6B8C")
      textSize = cardW * 0.02f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.LEFT
    }
    drawFlippedText(canvas, "ID LEVEL", trX - cardW * 0.05f, cardTop + cardH * 0.09f, idLevelLabelPaint)

    val idLevelValPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5C6BC0")
      textSize = cardW * 0.03f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.LEFT
    }
    drawFlippedText(canvas, "PLATINUM", trX - cardW * 0.05f, cardTop + cardH * 0.14f, idLevelValPaint)

    // Diamond inside Right Box
    val diamondCx = trX - cardW * 0.02f
    val diamondCy = cardTop + cardH * 0.11f
    val diaW = cardW * 0.04f
    val diaH = diaW
    val diaPath = Path().apply {
      moveTo(diamondCx, diamondCy - diaH / 2f)
      lineTo(diamondCx + diaW / 2f, diamondCy)
      lineTo(diamondCx, diamondCy + diaH / 2f)
      lineTo(diamondCx - diaW / 2f, diamondCy)
      close()
    }
    val diamondPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5C6BC0")
      style = Paint.Style.FILL
    }
    canvas.drawPath(diaPath, diamondPaint)

    val diamondLinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#E8EAF6")
      style = Paint.Style.STROKE
      strokeWidth = cardW * 0.003f
    }
    canvas.drawLine(diamondCx, diamondCy - diaH / 2f, diamondCx, diamondCy + diaH / 2f, diamondLinePaint)
    canvas.drawLine(diamondCx - diaW / 2f, diamondCy, diamondCx + diaW / 2f, diamondCy, diamondLinePaint)

    // 4. Photo Slot
    val photoSlotW = cardW * 0.30f
    val photoSlotH = photoSlotW * 1.25f
    val photoSlotL = cardLeft + cardW * 0.04f
    val photoSlotT = cardTop + cardH * 0.20f
    val photoSlotRect = RectF(photoSlotL, photoSlotT, photoSlotL + photoSlotW, photoSlotT + photoSlotH)
    val photoSlotRx = photoSlotW * 0.06f

    // Draw slot background base
    val slotBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#202228")
      style = Paint.Style.FILL
    }
    canvas.drawRoundRect(photoSlotRect, photoSlotRx, photoSlotRx, slotBgPaint)

    // Draw cropped face
    canvas.save()
    val clipPath = Path().apply {
      addRoundRect(photoSlotRect, photoSlotRx, photoSlotRx, Path.Direction.CW)
    }
    canvas.clipPath(clipPath)

    if (face != null) {
      val fBox = face.boundingBox
      val fCx = fBox.centerX()
      val fCy = fBox.centerY()
      val padW = fBox.width() * 1.4f
      val padH = padW * 1.25f

      val srcL = (fCx - padW / 2f).toInt().coerceIn(0, bitmap.width)
      val srcT = (fCy - padH * 0.6f).toInt().coerceIn(0, bitmap.height)
      val srcR = (fCx + padW / 2f).toInt().coerceIn(0, bitmap.width)
      val srcB = (fCy + padH * 0.4f).toInt().coerceIn(0, bitmap.height)
      val srcRect = Rect(srcL, srcT, srcR, srcB)

      canvas.drawBitmap(bitmap, srcRect, photoSlotRect, Paint(Paint.FILTER_BITMAP_FLAG))
    } else {
      val wFeed = bitmap.width.toFloat()
      val hFeed = bitmap.height.toFloat()
      val cropW = wFeed * 0.5f
      val cropH = cropW * 1.25f
      val srcL = ((wFeed - cropW) / 2f).toInt()
      val srcT = ((hFeed - cropH) / 2f).toInt()
      val srcRect = Rect(srcL, srcT, (srcL + cropW).toInt(), (srcT + cropH).toInt())

      canvas.drawBitmap(bitmap, srcRect, photoSlotRect, Paint(Paint.FILTER_BITMAP_FLAG))
    }
    canvas.restore()

    // Outer photo border
    val slotBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeWidth = photoSlotW * 0.024f
      shader = LinearGradient(
        photoSlotL, photoSlotT, photoSlotL + photoSlotW, photoSlotT + photoSlotH,
        intArrayOf(
          Color.parseColor("#9CB6FA"),
          Color.parseColor("#C39BFA")
        ),
        null,
        Shader.TileMode.CLAMP
      )
    }
    canvas.drawRoundRect(photoSlotRect, photoSlotRx, photoSlotRx, slotBorderPaint)

    // 5. Centered Stats on the Right Panel
    val fieldsL = photoSlotL + photoSlotW + cardW * 0.04f
    val rightAreaCx = fieldsL + (cardRight - cardW * 0.04f - fieldsL) / 2f
    
    val statLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5A6B8C")
      textSize = cardW * 0.024f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }

    val statValPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#0A3F9A")
      textSize = cardW * 0.045f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }

    val deluluValPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#D81B60")
      textSize = cardW * 0.045f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }

    val startY = cardTop + cardH * 0.32f
    val yGap = cardH * 0.18f

    // Delulu Level
    drawFlippedText(canvas, "DELULU LEVEL", rightAreaCx, startY - cardH * 0.035f, statLabelPaint)
    drawFlippedText(canvas, ": $cardDeluluLevel", rightAreaCx, startY + cardH * 0.035f, deluluValPaint)

    // Sleep Hours
    drawFlippedText(canvas, "SLEEP HOURS", rightAreaCx, startY + yGap - cardH * 0.035f, statLabelPaint)
    drawFlippedText(canvas, ": $cardSleepHours", rightAreaCx, startY + yGap + cardH * 0.035f, statValPaint)

    // Attention Rate
    drawFlippedText(canvas, "ATTENTION RATE", rightAreaCx, startY + 2 * yGap - cardH * 0.035f, statLabelPaint)
    drawFlippedText(canvas, ": $cardAttentionRate", rightAreaCx, startY + 2 * yGap + cardH * 0.035f, statValPaint)

    // 7. Bottom Banner
    val bannerRect = RectF(cardLeft, cardTop + cardH * 0.85f, cardRight, cardBottom)
    val bannerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
      shader = LinearGradient(
        cardLeft, cardTop + cardH * 0.85f, cardRight, cardBottom,
        intArrayOf(
          Color.parseColor("#E2E7FC"),
          Color.parseColor("#EBF0FE")
        ),
        null,
        Shader.TileMode.CLAMP
      )
    }

    canvas.save()
    val cardPath = Path().apply {
      addRoundRect(cardRect, cardRx, cardRx, Path.Direction.CW)
    }
    canvas.clipPath(cardPath)
    canvas.drawRect(bannerRect, bannerPaint)

    // Verified Shield Icon in bottom-left
    val bsX = cardLeft + cardW * 0.08f
    val bsY = cardTop + cardH * 0.925f
    val bsW = cardW * 0.05f
    val bsH = bsW * 1.1f

    val bsShieldPath = Path().apply {
      moveTo(bsX, bsY - bsH / 2f)
      cubicTo(bsX + bsW / 3f, bsY - bsH / 2f, bsX + bsW / 2f, bsY - bsH / 4f, bsX + bsW / 2f, bsY)
      cubicTo(bsX + bsW / 2f, bsY + bsH / 3f, bsX + bsW / 4f, bsY + bsH / 2f, bsX, bsY + bsH / 2f)
      cubicTo(bsX - bsW / 4f, bsY + bsH / 2f, bsX - bsW / 2f, bsY + bsH / 3f, bsX - bsW / 2f, bsY)
      cubicTo(bsX - bsW / 2f, bsY - bsH / 4f, bsX - bsW / 3f, bsY - bsH / 2f, bsX, bsY - bsH / 2f)
      close()
    }
    val bsShieldPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5C6BC0")
      style = Paint.Style.FILL
    }
    canvas.drawPath(bsShieldPath, bsShieldPaint)

    val checkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = cardW * 0.006f
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
    }
    val checkPath = Path().apply {
      moveTo(bsX - bsW * 0.22f, bsY)
      lineTo(bsX - bsW * 0.05f, bsY + bsH * 0.15f)
      lineTo(bsX + bsW * 0.22f, bsY - bsH * 0.18f)
    }
    canvas.drawPath(checkPath, checkPaint)

    // Bottom banner text
    val bannerTextPaint1 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#0A3F9A")
      textSize = cardW * 0.028f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
    }
    drawFlippedText(canvas, "OFFICIAL LENS+ CITIZEN", headerCx, cardTop + cardH * 0.91f, bannerTextPaint1)

    val bannerTextPaint2 = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#5C6BC0")
      textSize = cardW * 0.018f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
      letterSpacing = 0.06f
    }
    drawFlippedText(canvas, "VERIFIED  •  ACTIVE  •  LEGENDARY", headerCx, cardTop + cardH * 0.96f, bannerTextPaint2)

    canvas.restore()
  }

  private fun drawFlippedIcon(canvas: Canvas, x: Float, y: Float, action: (Canvas) -> Unit) {
    canvas.save()
    canvas.translate(x, y)
    if (isFrontCamera) {
      canvas.scale(-1f, 1f)
    }
    action(canvas)
    canvas.restore()
  }

  fun drawCreatorHud(canvas: Canvas, bitmap: Bitmap) {
    val w = bitmap.width.toFloat()
    val h = bitmap.height.toFloat()

    canvas.save()

    // 1. Paint styles
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.STROKE
      strokeWidth = w * 0.006f
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
      setShadowLayer(6f, 0f, 3f, Color.parseColor("#80000000"))
    }

    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      style = Paint.Style.FILL
      setShadowLayer(6f, 0f, 3f, Color.parseColor("#80000000"))
    }

    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      textSize = w * 0.026f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.CENTER
      setShadowLayer(6f, 0f, 3f, Color.parseColor("#80000000"))
    }

    val r = w * 0.024f // Icon base radius

    // 2. Draw Left Sidebar Overlays (Heart, Share, Eye + Viewer Count)
    // To appear on the left side of the screen, draw at local coordinate x = w * 0.93f
    val hudLeftX = w * 0.93f
    
    // Heart Icon at y = h * 0.15f
    val heartY = h * 0.15f
    drawFlippedIcon(canvas, hudLeftX, heartY) { c ->
      val heartPath = Path().apply {
        moveTo(0f, -r * 0.3f)
        cubicTo(-r * 0.6f, -r * 0.9f, -r * 1.2f, -r * 0.2f, 0f, r * 0.8f)
        cubicTo(r * 1.2f, -r * 0.2f, r * 0.6f, -r * 0.9f, 0f, -r * 0.3f)
        close()
      }
      c.drawPath(heartPath, strokePaint)
    }

    // Share/Arrow Icon at y = h * 0.23f
    val shareY = h * 0.23f
    drawFlippedIcon(canvas, hudLeftX, shareY) { c ->
      val arrowPath = Path().apply {
        // Curved tail
        moveTo(-r * 0.5f, r * 0.3f)
        quadTo(0f, 0f, r * 0.3f, -r * 0.2f)
        // Arrow head pointing right (positive x in flipped space)
        moveTo(r * 0.1f, -r * 0.5f)
        lineTo(r * 0.5f, -r * 0.2f)
        lineTo(r * 0.1f, r * 0.1f)
      }
      c.drawPath(arrowPath, strokePaint)
    }

    // Eye Icon at y = h * 0.31f
    val eyeY = h * 0.31f
    drawFlippedIcon(canvas, hudLeftX, eyeY) { c ->
      val eyePath = Path().apply {
        moveTo(-r * 0.8f, 0f)
        quadTo(0f, -r * 0.5f, r * 0.8f, 0f)
        quadTo(0f, r * 0.5f, -r * 0.8f, 0f)
        close()
      }
      c.drawPath(eyePath, strokePaint)
      c.drawCircle(0f, 0f, r * 0.25f, fillPaint)
    }

    // Viewer Count Text (e.g. "1.2TCR") at y = h * 0.36f
    // Draw flipped text centered at hudLeftX
    drawFlippedText(canvas, creatorViewerCount, hudLeftX, eyeY + r * 1.4f, textPaint)

    // 3. Draw Right Sidebar Overlays (Music, Dropdown Arrow)
    // To appear on the right side of the screen, draw at local coordinate x = w * 0.07f
    val hudRightX = w * 0.07f

    // Music Note Icon at y = h * 0.15f
    val musicY = h * 0.15f
    drawFlippedIcon(canvas, hudRightX, musicY) { c ->
      val musicPath = Path().apply {
        // Stems
        moveTo(-r * 0.2f, r * 0.4f)
        lineTo(-r * 0.2f, -r * 0.6f)
        lineTo(r * 0.4f, -r * 0.4f)
        lineTo(r * 0.4f, r * 0.6f)
        // Beam top
        moveTo(-r * 0.2f, -r * 0.6f)
        lineTo(r * 0.4f, -r * 0.4f)
      }
      c.drawPath(musicPath, strokePaint)
      c.drawCircle(-r * 0.4f, r * 0.4f, r * 0.2f, fillPaint)
      c.drawCircle(r * 0.2f, r * 0.6f, r * 0.2f, fillPaint)
    }

    // Dropdown Arrow at y = h * 0.23f
    val dropY = h * 0.23f
    drawFlippedIcon(canvas, hudRightX, dropY) { c ->
      val dropPath = Path().apply {
        moveTo(-r * 0.4f, -r * 0.2f)
        lineTo(0f, r * 0.2f)
        lineTo(r * 0.4f, -r * 0.2f)
      }
      c.drawPath(dropPath, strokePaint)
    }

    // 4. Draw Top Music Banner: "Noor E Khuda (L..."
    // Positioned at top center: bannerY = h * 0.05f
    val bannerCx = w / 2f
    val bannerY = h * 0.045f
    val bannerW = w * 0.48f
    val bannerH = h * 0.038f

    // Semi-transparent background pill
    val pillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#66000000") // 40% black
    }
    val pillRect = RectF(bannerCx - bannerW / 2f, bannerY, bannerCx + bannerW / 2f, bannerY + bannerH)
    canvas.drawRoundRect(pillRect, bannerH / 2f, bannerH / 2f, pillPaint)

    // Music note icon inside pill
    val noteX = bannerCx - bannerW / 2f + bannerH * 0.6f
    val noteY = bannerY + bannerH / 2f
    val noteR = bannerH * 0.22f
    drawFlippedIcon(canvas, noteX, noteY) { c ->
      val notePath = Path().apply {
        moveTo(-noteR * 0.2f, noteR * 0.4f)
        lineTo(-noteR * 0.2f, -noteR * 0.6f)
        lineTo(noteR * 0.4f, -noteR * 0.4f)
        lineTo(noteR * 0.4f, noteR * 0.6f)
        moveTo(-noteR * 0.2f, -noteR * 0.6f)
        lineTo(noteR * 0.4f, -noteR * 0.4f)
      }
      val noteStroke = Paint(strokePaint).apply { strokeWidth = noteR * 0.2f; setShadowLayer(0f, 0f, 0f, 0) }
      val noteFill = Paint(fillPaint).apply { setShadowLayer(0f, 0f, 0f, 0) }
      c.drawPath(notePath, noteStroke)
      c.drawCircle(-noteR * 0.4f, noteR * 0.4f, noteR * 0.2f, noteFill)
      c.drawCircle(noteR * 0.2f, noteR * 0.6f, noteR * 0.2f, noteFill)
    }

    // Music title text
    val bannerTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      textSize = bannerH * 0.38f
      typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.BOLD)
      textAlign = Paint.Align.RIGHT // Right aligned in mirrored space = Left aligned in screen space
    }
    drawFlippedText(canvas, "Noor E Khuda (L...", noteX + bannerH * 0.7f, bannerY + bannerH * 0.62f, bannerTextPaint)

    // Vertical line divider inside pill
    val dividerX = bannerCx + bannerW / 2f - bannerH * 1.2f
    val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.parseColor("#40FFFFFF") // 25% white
      strokeWidth = w * 0.003f
    }
    canvas.drawLine(dividerX, bannerY + bannerH * 0.25f, dividerX, bannerY + bannerH * 0.75f, dividerPaint)

    // Plus icon on the right side of divider inside pill
    val plusX = bannerCx + bannerW / 2f - bannerH * 0.6f
    val plusY = bannerY + bannerH / 2f
    val plusSize = bannerH * 0.2f
    canvas.drawLine(plusX - plusSize, plusY, plusX + plusSize, plusY, strokePaint)
    canvas.drawLine(plusX, plusY - plusSize, plusX, plusY + plusSize, strokePaint)

    canvas.restore()
  }
}

