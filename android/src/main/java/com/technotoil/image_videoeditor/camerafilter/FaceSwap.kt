package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import kotlin.math.max

object FaceSwap {
  private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

  private fun faceCenter(face: DetectedFace): PointF {
    val le = leftEye(face)
    val re = rightEye(face)
    val nose = noseBase(face)
    if (le != null && re != null && nose != null) {
      return PointF((le.x + re.x + nose.x) / 3, (le.y + re.y + nose.y) / 3)
    }
    val b = face.boundingBox
    return PointF(b.centerX(), b.centerY())
  }

  private fun faceRadius(face: DetectedFace): Float {
    val b = face.boundingBox
    return max(b.width(), b.height()) * 0.55f
  }

  private fun swapOnto(canvas: Canvas, frame: Bitmap, target: DetectedFace, source: DetectedFace) {
    val targetCenter = faceCenter(target)
    val sourceCenter = faceCenter(source)
    val targetRadius = faceRadius(target)
    val sourceRadius = faceRadius(source)
    val scale = targetRadius / sourceRadius
    val rotation = target.rollAngle - source.rollAngle

    canvas.save()

    val clip = Path()
    clip.addOval(
      RectF(
        targetCenter.x - targetRadius, targetCenter.y - targetRadius,
        targetCenter.x + targetRadius, targetCenter.y + targetRadius,
      ),
      Path.Direction.CW,
    )
    canvas.clipPath(clip)

    canvas.translate(targetCenter.x, targetCenter.y)
    canvas.rotate(rotation)
    canvas.scale(scale, scale)
    canvas.translate(-sourceCenter.x, -sourceCenter.y)
    canvas.drawBitmap(frame, 0f, 0f, paint)

    canvas.restore()
  }

  fun draw(canvas: Canvas, frame: Bitmap, faces: List<DetectedFace>) {
    if (faces.size < 2) return
    val sorted = faces.sortedByDescending { it.boundingBox.width() * it.boundingBox.height() }
    val faceA = sorted[0]
    val faceB = sorted[1]
    swapOnto(canvas, frame, faceA, faceB)
    swapOnto(canvas, frame, faceB, faceA)
  }
}
