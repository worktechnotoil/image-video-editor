package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Path
import android.graphics.PointF
import android.graphics.RectF
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceLandmark

/**
 * Plain, pre-scaled snapshot of an ML Kit Face. Detection runs on a downscaled copy of the
 * frame for speed, so every coordinate here is multiplied by `1 / detectionScale` right after
 * detection completes, letting every filter below draw directly in full-resolution display
 * coordinates without needing to know about the detection/display resolution split.
 */
class DetectedFace(
  val boundingBox: RectF,
  val rollAngle: Float,
  val yawAngle: Float,
  val pitchAngle: Float,
  val leftEye: PointF?,
  val rightEye: PointF?,
  val noseBase: PointF?,
  val leftEar: PointF?,
  val rightEar: PointF?,
  val leftCheek: PointF?,
  val rightCheek: PointF?,
  val faceContour: List<PointF>?,
  val upperLip: List<PointF>?,
  val lowerLip: List<PointF>?,
  val upperLipBottom: List<PointF>?,
  val lowerLipTop: List<PointF>?,
  val smilingProbability: Float?,
  val leftEyeOpenProbability: Float?,
  val rightEyeOpenProbability: Float?
) {
  var smoothedEyeDistance: Float = 0f
}

private fun scalePoint(p: PointF, scale: Float): PointF = PointF(p.x * scale, p.y * scale)

fun toDetectedFace(face: Face, scale: Float): DetectedFace {
  fun landmark(type: Int): PointF? = face.getLandmark(type)?.position?.let { scalePoint(it, scale) }
  fun contour(type: Int): List<PointF>? = face.getContour(type)?.points?.map { scalePoint(it, scale) }

  val b = face.boundingBox
  return DetectedFace(
    boundingBox = RectF(b.left * scale, b.top * scale, b.right * scale, b.bottom * scale),
    rollAngle = face.headEulerAngleZ,
    yawAngle = face.headEulerAngleY,
    pitchAngle = face.headEulerAngleX,
    leftEye = landmark(FaceLandmark.LEFT_EYE),
    rightEye = landmark(FaceLandmark.RIGHT_EYE),
    noseBase = landmark(FaceLandmark.NOSE_BASE),
    leftEar = landmark(FaceLandmark.LEFT_EAR),
    rightEar = landmark(FaceLandmark.RIGHT_EAR),
    leftCheek = landmark(FaceLandmark.LEFT_CHEEK),
    rightCheek = landmark(FaceLandmark.RIGHT_CHEEK),
    faceContour = contour(FaceContour.FACE),
    upperLip = contour(FaceContour.UPPER_LIP_TOP),
    lowerLip = contour(FaceContour.LOWER_LIP_BOTTOM),
    upperLipBottom = contour(FaceContour.UPPER_LIP_BOTTOM),
    lowerLipTop = contour(FaceContour.LOWER_LIP_TOP),
    smilingProbability = face.smilingProbability,
    leftEyeOpenProbability = face.leftEyeOpenProbability,
    rightEyeOpenProbability = face.rightEyeOpenProbability,
  )
}

private fun pathFromPoints(points: List<PointF>): Path {
  val path = Path()
  path.moveTo(points[0].x, points[0].y)
  for (i in 1 until points.size) path.lineTo(points[i].x, points[i].y)
  path.close()
  return path
}

fun faceOvalPath(face: DetectedFace): Path? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  return pathFromPoints(points)
}

fun mouthPath(face: DetectedFace): Path? {
  val upper = face.upperLip
  val lower = face.lowerLip
  if (upper.isNullOrEmpty() || lower.isNullOrEmpty()) return null
  val path = Path()
  path.moveTo(upper[0].x, upper[0].y)
  for (i in 1 until upper.size) path.lineTo(upper[i].x, upper[i].y)
  for (i in lower.size - 1 downTo 0) path.lineTo(lower[i].x, lower[i].y)
  path.close()
  return path
}

fun upperLipPath(face: DetectedFace): Path? {
  val top = face.upperLip
  val bottom = face.upperLipBottom
  if (top.isNullOrEmpty() || bottom.isNullOrEmpty()) return null
  val path = Path()
  path.moveTo(top[0].x, top[0].y)
  for (i in 1 until top.size) path.lineTo(top[i].x, top[i].y)
  for (i in bottom.size - 1 downTo 0) path.lineTo(bottom[i].x, bottom[i].y)
  path.close()
  return path
}

fun lowerLipPath(face: DetectedFace): Path? {
  val top = face.lowerLipTop
  val bottom = face.lowerLip
  if (top.isNullOrEmpty() || bottom.isNullOrEmpty()) return null
  val path = Path()
  path.moveTo(top[0].x, top[0].y)
  for (i in 1 until top.size) path.lineTo(top[i].x, top[i].y)
  for (i in bottom.size - 1 downTo 0) path.lineTo(bottom[i].x, bottom[i].y)
  path.close()
  return path
}

fun topOfHeadPoint(face: DetectedFace): PointF? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  var top = points[0]
  for (p in points) if (p.y < top.y) top = p
  return top
}

fun bottomOfFacePoint(face: DetectedFace): PointF? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  var bottom = points[0]
  for (p in points) if (p.y > bottom.y) bottom = p
  return bottom
}

fun leftMostFacePoint(face: DetectedFace): PointF? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  var left = points[0]
  for (p in points) if (p.x < left.x) left = p
  return left
}

fun rightMostFacePoint(face: DetectedFace): PointF? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  var right = points[0]
  for (p in points) if (p.x > right.x) right = p
  return right
}

fun topLeftFacePoint(face: DetectedFace): PointF? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  val centerX = face.boundingBox.centerX()
  var candidate: PointF? = null
  for (p in points) {
    if (p.x <= centerX) {
      if (candidate == null || p.y < candidate!!.y || (p.y == candidate!!.y && p.x > candidate!!.x)) {
        candidate = p
      }
    }
  }
  return candidate ?: leftMostFacePoint(face)
}

fun topRightFacePoint(face: DetectedFace): PointF? {
  val points = face.faceContour
  if (points.isNullOrEmpty()) return null
  val centerX = face.boundingBox.centerX()
  var candidate: PointF? = null
  for (p in points) {
    if (p.x >= centerX) {
      if (candidate == null || p.y < candidate!!.y || (p.y == candidate!!.y && p.x < candidate!!.x)) {
        candidate = p
      }
    }
  }
  return candidate ?: rightMostFacePoint(face)
}

fun leftEye(face: DetectedFace): PointF? = face.leftEye
fun rightEye(face: DetectedFace): PointF? = face.rightEye
fun noseBase(face: DetectedFace): PointF? = face.noseBase
fun leftEar(face: DetectedFace): PointF? = face.leftEar
fun rightEar(face: DetectedFace): PointF? = face.rightEar
fun leftCheek(face: DetectedFace): PointF? = face.leftCheek
fun rightCheek(face: DetectedFace): PointF? = face.rightCheek

fun eyeDistance(face: DetectedFace): Float {
  val l = face.leftEye ?: return 0f
  val r = face.rightEye ?: return 0f
  return kotlin.math.hypot((r.x - l.x).toDouble(), (r.y - l.y).toDouble()).toFloat()
}
