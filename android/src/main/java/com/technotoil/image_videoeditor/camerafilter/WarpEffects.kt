package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.os.Build
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RuntimeShader
import android.graphics.Shader
import androidx.annotation.RequiresApi
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

const val MAX_CONTROL_POINTS = 6

data class ControlPoint(val x: Float, val y: Float, val radius: Float, val strength: Float)

// AGSL port of the SKSL warp shader in src/filters/warpShader.ts.
private const val WARP_AGSL = """
uniform shader image;
uniform float4 cp0;
uniform float4 cp1;
uniform float4 cp2;
uniform float4 cp3;
uniform float4 cp4;
uniform float4 cp5;

vec2 warpOffset(vec2 coord, vec4 cp) {
  float radius = cp.z;
  if (radius <= 0.0) {
    return vec2(0.0);
  }
  vec2 center = cp.xy;
  vec2 diff = coord - center;
  float dist = length(diff);
  if (dist >= radius || dist < 0.0001) {
    return vec2(0.0);
  }
  float normalized = dist / radius;
  float falloff = 1.0 - smoothstep(0.0, 1.0, normalized);
  vec2 dir = diff / dist;
  return dir * cp.w * falloff;
}

half4 main(vec2 coord) {
  vec2 displacement = vec2(0.0);
  displacement += warpOffset(coord, cp0);
  displacement += warpOffset(coord, cp1);
  displacement += warpOffset(coord, cp2);
  displacement += warpOffset(coord, cp3);
  displacement += warpOffset(coord, cp4);
  displacement += warpOffset(coord, cp5);
  return image.eval(coord - displacement);
}
"""

object WarpEffects {
  private var shader: RuntimeShader? = null
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

  @RequiresApi(33)
  private fun getShader(): RuntimeShader {
    var s = shader
    if (s == null) {
      s = RuntimeShader(WARP_AGSL)
      shader = s
    }
    return s
  }

  fun apply(canvas: Canvas, frame: Bitmap, points: List<ControlPoint>) {
    if (points.isEmpty()) {
      canvas.drawBitmap(frame, 0f, 0f, null)
      return
    }
    if (Build.VERSION.SDK_INT >= 33) {
      applyGpu(canvas, frame, points)
    } else {
      applyCpu(canvas, frame, points)
    }
  }

  @RequiresApi(33)
  private fun applyGpu(canvas: Canvas, frame: Bitmap, points: List<ControlPoint>) {
    val rs = getShader()
    val imageShader = BitmapShader(frame, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
    rs.setInputShader("image", imageShader)
    for (i in 0 until MAX_CONTROL_POINTS) {
      val p = points.getOrNull(i)
      rs.setFloatUniform(
        "cp$i",
        p?.x ?: 0f, p?.y ?: 0f, p?.radius ?: 0f, p?.strength ?: 0f,
      )
    }
    paint.shader = rs
    canvas.drawRect(0f, 0f, frame.width.toFloat(), frame.height.toFloat(), paint)
    paint.shader = null
  }

  /** CPU fallback for pre-API-33 devices: only touches pixels inside each control point's bounding box. */
  private fun applyCpu(canvas: Canvas, frame: Bitmap, points: List<ControlPoint>) {
    val output = frame.copy(Bitmap.Config.ARGB_8888, true)
    val width = frame.width
    val height = frame.height
    val srcPixels = IntArray(width * height)
    frame.getPixels(srcPixels, 0, width, 0, 0, width, height)

    for (point in points) {
      val minX = max(0, (point.x - point.radius).toInt())
      val maxX = min(width - 1, (point.x + point.radius).toInt())
      val minY = max(0, (point.y - point.radius).toInt())
      val maxY = min(height - 1, (point.y + point.radius).toInt())
      if (point.radius <= 0f) continue

      val regionW = maxX - minX + 1
      if (regionW <= 0 || maxY - minY + 1 <= 0) continue
      val regionPixels = IntArray(regionW * (maxY - minY + 1))

      for (y in minY..maxY) {
        for (x in minX..maxX) {
          val dx = x - point.x
          val dy = y - point.y
          val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
          val idx = (y - minY) * regionW + (x - minX)
          if (dist >= point.radius || dist < 0.0001f) {
            regionPixels[idx] = srcPixels[y * width + x]
            continue
          }
          val normalized = dist / point.radius
          val falloff = 1f - smoothstep(normalized)
          val dirX = dx / dist
          val dirY = dy / dist
          val srcX = (x - dirX * point.strength * falloff).toInt().coerceIn(0, width - 1)
          val srcY = (y - dirY * point.strength * falloff).toInt().coerceIn(0, height - 1)
          regionPixels[idx] = srcPixels[srcY * width + srcX]
        }
      }
      output.setPixels(regionPixels, 0, regionW, minX, minY, regionW, maxY - minY + 1)
    }

    canvas.drawBitmap(output, 0f, 0f, null)
  }

  private fun smoothstep(t: Float): Float {
    val x = t.coerceIn(0f, 1f)
    return x * x * (3f - 2f * x)
  }
}

private fun eyeDist(face: DetectedFace): Float = eyeDistance(face)

fun eyeEnhancePoints(face: DetectedFace): List<ControlPoint> {
  val le = leftEye(face) ?: return emptyList()
  val re = rightEye(face) ?: return emptyList()
  val dist = eyeDist(face)
  if (dist == 0f) return emptyList()
  val radius = dist * 0.45f
  val strength = dist * 0.16f
  return listOf(
    ControlPoint(le.x, le.y, radius, strength),
    ControlPoint(re.x, re.y, radius, strength),
  )
}

fun slimFacePoints(face: DetectedFace): List<ControlPoint> {
  val lc = leftCheek(face) ?: return emptyList()
  val rc = rightCheek(face) ?: return emptyList()
  val dist = eyeDist(face)
  if (dist == 0f) return emptyList()
  val radius = dist * 0.9f
  val strength = -dist * 0.18f
  return listOf(
    ControlPoint(lc.x, lc.y, radius, strength),
    ControlPoint(rc.x, rc.y, radius, strength),
  )
}

fun fisheyePoints(face: DetectedFace): List<ControlPoint> {
  val dist = eyeDist(face)
  if (dist == 0f) return emptyList()
  val b = face.boundingBox
  val cx = b.centerX()
  val cy = b.centerY()
  return listOf(ControlPoint(cx, cy, b.width() * 0.95f, dist * 0.28f))
}

fun babyFacePoints(face: DetectedFace): List<ControlPoint> {
  return (eyeEnhancePoints(face) + slimFacePoints(face)).take(MAX_CONTROL_POINTS)
}
