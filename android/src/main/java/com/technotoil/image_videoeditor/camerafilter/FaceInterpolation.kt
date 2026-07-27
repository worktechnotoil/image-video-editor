package com.technotoil.image_videoeditor.camerafilter

import android.graphics.PointF
import android.graphics.RectF
import kotlin.math.hypot

private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

private fun lerpPoint(a: PointF, b: PointF, t: Float) = PointF(lerp(a.x, b.x, t), lerp(a.y, b.y, t))

private fun lerpFloatOrNull(a: Float?, b: Float?, t: Float): Float? {
  if (a == null || b == null) return b
  return lerp(a, b, t)
}

private fun lerpPointOrNull(a: PointF?, b: PointF?, t: Float): PointF? {
  if (a == null || b == null) return b
  return lerpPoint(a, b, t)
}

private fun lerpPointList(a: List<PointF>?, b: List<PointF>?, t: Float): List<PointF>? {
  if (a == null || b == null || a.size != b.size) return b
  return List(a.size) { lerpPoint(a[it], b[it], t) }
}

private fun lerpFace(a: DetectedFace, b: DetectedFace, t: Float): DetectedFace {
  return DetectedFace(
    boundingBox = RectF(
      lerp(a.boundingBox.left, b.boundingBox.left, t),
      lerp(a.boundingBox.top, b.boundingBox.top, t),
      lerp(a.boundingBox.right, b.boundingBox.right, t),
      lerp(a.boundingBox.bottom, b.boundingBox.bottom, t),
    ),
    rollAngle = lerp(a.rollAngle, b.rollAngle, t),
    yawAngle = lerp(a.yawAngle, b.yawAngle, t),
    pitchAngle = lerp(a.pitchAngle, b.pitchAngle, t),
    leftEye = lerpPointOrNull(a.leftEye, b.leftEye, t),
    rightEye = lerpPointOrNull(a.rightEye, b.rightEye, t),
    noseBase = lerpPointOrNull(a.noseBase, b.noseBase, t),
    leftEar = lerpPointOrNull(a.leftEar, b.leftEar, t),
    rightEar = lerpPointOrNull(a.rightEar, b.rightEar, t),
    leftCheek = lerpPointOrNull(a.leftCheek, b.leftCheek, t),
    rightCheek = lerpPointOrNull(a.rightCheek, b.rightCheek, t),
    faceContour = lerpPointList(a.faceContour, b.faceContour, t),
    upperLip = lerpPointList(a.upperLip, b.upperLip, t),
    lowerLip = lerpPointList(a.lowerLip, b.lowerLip, t),
    upperLipBottom = lerpPointList(a.upperLipBottom, b.upperLipBottom, t),
    lowerLipTop = lerpPointList(a.lowerLipTop, b.lowerLipTop, t),
    smilingProbability = lerpFloatOrNull(a.smilingProbability, b.smilingProbability, t),
    leftEyeOpenProbability = lerpFloatOrNull(a.leftEyeOpenProbability, b.leftEyeOpenProbability, t),
    rightEyeOpenProbability = lerpFloatOrNull(a.rightEyeOpenProbability, b.rightEyeOpenProbability, t),
  )
}

class FaceVelocity {
  var vx: Float = 0f
  var vy: Float = 0f
  var vRoll: Float = 0f
  var vYaw: Float = 0f
  var vPitch: Float = 0f
  var smoothedEyeDistance: Float = 0f
  private val alpha = 0.5f

  fun update(prev: DetectedFace, curr: DetectedFace, dtMs: Float) {
    if (dtMs <= 0f) return
    val rawVx = (curr.boundingBox.centerX() - prev.boundingBox.centerX()) / dtMs
    val rawVy = (curr.boundingBox.centerY() - prev.boundingBox.centerY()) / dtMs
    val rawVRoll = (curr.rollAngle - prev.rollAngle) / dtMs
    val rawVYaw = (curr.yawAngle - prev.yawAngle) / dtMs
    val rawVPitch = (curr.pitchAngle - prev.pitchAngle) / dtMs

    vx = lerp(vx, rawVx, alpha)
    vy = lerp(vy, rawVy, alpha)
    vRoll = lerp(vRoll, rawVRoll, alpha)
    vYaw = lerp(vYaw, rawVYaw, alpha)
    vPitch = lerp(vPitch, rawVPitch, alpha)

    val currDist = curr.leftEye?.let { le ->
      curr.rightEye?.let { re ->
        hypot((re.x - le.x).toDouble(), (re.y - le.y).toDouble()).toFloat()
      }
    } ?: 0f
    if (currDist > 0f) {
      smoothedEyeDistance = if (smoothedEyeDistance == 0f) currDist else lerp(smoothedEyeDistance, currDist, 0.15f)
    }
  }

  fun reset() {
    vx = 0f
    vy = 0f
    vRoll = 0f
    vYaw = 0f
    vPitch = 0f
    smoothedEyeDistance = 0f
  }
}

private fun predictPoint(lerped: PointF?, curr: PointF?, vx: Float, vy: Float, elapsedMs: Float, blend: Float): PointF? {
  if (lerped == null || curr == null) return lerped ?: curr
  val predictedX = curr.x + vx * elapsedMs
  val predictedY = curr.y + vy * elapsedMs
  return PointF(
    lerp(lerped.x, predictedX, blend),
    lerp(lerped.y, predictedY, blend),
  )
}

private fun predictPointList(lerped: List<PointF>?, curr: List<PointF>?, vx: Float, vy: Float, elapsedMs: Float, blend: Float): List<PointF>? {
  if (lerped == null || curr == null || lerped.size != curr.size) return lerped ?: curr
  return List(lerped.size) { i ->
    val l = lerped[i]
    val c = curr[i]
    val predictedX = c.x + vx * elapsedMs
    val predictedY = c.y + vy * elapsedMs
    PointF(
      lerp(l.x, predictedX, blend),
      lerp(l.y, predictedY, blend)
    )
  }
}

fun updateVelocities(prev: List<DetectedFace>, curr: List<DetectedFace>, vels: MutableList<FaceVelocity>, dtMs: Float) {
  if (prev.isEmpty() || curr.isEmpty() || dtMs <= 0f) {
    if (curr.isEmpty()) vels.clear()
    return
  }

  val matched = matchPrevious(prev, curr)
  
  // Clean up unused velocities or scale size
  while (vels.size > curr.size) {
    vels.removeAt(vels.size - 1)
  }
  while (vels.size < curr.size) {
    vels.add(FaceVelocity())
  }

  curr.forEachIndexed { idx, c ->
    val p = matched[idx]
    if (p != null) {
      vels[idx].update(p, c, dtMs)
    } else {
      vels[idx].reset()
    }
  }
}

fun interpolateFaces(
  prev: List<DetectedFace>,
  curr: List<DetectedFace>,
  t: Float,
  vels: List<FaceVelocity>,
  elapsedMs: Float,
  intervalMs: Float
): List<DetectedFace> {
  if (prev.isEmpty() || curr.isEmpty()) return curr

  val matched = matchPrevious(prev, curr)
  val tClamped = t.coerceIn(0f, 2.0f) // Allow slight extrapolation

  return curr.mapIndexed { idx, c ->
    val p = matched[idx] ?: return@mapIndexed c
    val lerpedFaceResult = lerpFace(p, c, tClamped)

    val vel = if (idx < vels.size) vels[idx] else null
    if (vel == null) return@mapIndexed lerpedFaceResult

    // Dynamic predictive blend based on speed to prevent lag
    val speed = hypot(vel.vx.toDouble(), vel.vy.toDouble()).toFloat()
    val maxSpeed = c.boundingBox.width() * 0.05f
    val predictionBlend = (speed / maxSpeed).coerceIn(0f, 1f) * (elapsedMs / intervalMs).coerceIn(0f, 1f)

    if (predictionBlend < 0.01f) {
      lerpedFaceResult.smoothedEyeDistance = vel.smoothedEyeDistance
      return@mapIndexed lerpedFaceResult
    }

    val finalFace = DetectedFace(
      boundingBox = RectF(
        lerp(lerpedFaceResult.boundingBox.left, c.boundingBox.left + vel.vx * elapsedMs, predictionBlend),
        lerp(lerpedFaceResult.boundingBox.top, c.boundingBox.top + vel.vy * elapsedMs, predictionBlend),
        lerp(lerpedFaceResult.boundingBox.right, c.boundingBox.right + vel.vx * elapsedMs, predictionBlend),
        lerp(lerpedFaceResult.boundingBox.bottom, c.boundingBox.bottom + vel.vy * elapsedMs, predictionBlend),
      ),
      rollAngle = lerp(lerpedFaceResult.rollAngle, c.rollAngle + vel.vRoll * elapsedMs, predictionBlend),
      yawAngle = lerp(lerpedFaceResult.yawAngle, c.yawAngle + vel.vYaw * elapsedMs, predictionBlend),
      pitchAngle = lerp(lerpedFaceResult.pitchAngle, c.pitchAngle + vel.vPitch * elapsedMs, predictionBlend),
      leftEye = predictPoint(lerpedFaceResult.leftEye, c.leftEye, vel.vx, vel.vy, elapsedMs, predictionBlend),
      rightEye = predictPoint(lerpedFaceResult.rightEye, c.rightEye, vel.vx, vel.vy, elapsedMs, predictionBlend),
      noseBase = predictPoint(lerpedFaceResult.noseBase, c.noseBase, vel.vx, vel.vy, elapsedMs, predictionBlend),
      leftEar = predictPoint(lerpedFaceResult.leftEar, c.leftEar, vel.vx, vel.vy, elapsedMs, predictionBlend),
      rightEar = predictPoint(lerpedFaceResult.rightEar, c.rightEar, vel.vx, vel.vy, elapsedMs, predictionBlend),
      leftCheek = predictPoint(lerpedFaceResult.leftCheek, c.leftCheek, vel.vx, vel.vy, elapsedMs, predictionBlend),
      rightCheek = predictPoint(lerpedFaceResult.rightCheek, c.rightCheek, vel.vx, vel.vy, elapsedMs, predictionBlend),
      faceContour = predictPointList(lerpedFaceResult.faceContour, c.faceContour, vel.vx, vel.vy, elapsedMs, predictionBlend),
      upperLip = predictPointList(lerpedFaceResult.upperLip, c.upperLip, vel.vx, vel.vy, elapsedMs, predictionBlend),
      lowerLip = predictPointList(lerpedFaceResult.lowerLip, c.lowerLip, vel.vx, vel.vy, elapsedMs, predictionBlend),
      upperLipBottom = predictPointList(lerpedFaceResult.upperLipBottom, c.upperLipBottom, vel.vx, vel.vy, elapsedMs, predictionBlend),
      lowerLipTop = predictPointList(lerpedFaceResult.lowerLipTop, c.lowerLipTop, vel.vx, vel.vy, elapsedMs, predictionBlend),
      smilingProbability = lerpFloatOrNull(lerpedFaceResult.smilingProbability, c.smilingProbability, predictionBlend),
      leftEyeOpenProbability = lerpFloatOrNull(lerpedFaceResult.leftEyeOpenProbability, c.leftEyeOpenProbability, predictionBlend),
      rightEyeOpenProbability = lerpFloatOrNull(lerpedFaceResult.rightEyeOpenProbability, c.rightEyeOpenProbability, predictionBlend),
    )
    finalFace.smoothedEyeDistance = vel.smoothedEyeDistance
    finalFace
  }
}

private fun matchPrevious(prev: List<DetectedFace>, curr: List<DetectedFace>): List<DetectedFace?> {
  val used = BooleanArray(prev.size)
  return curr.map { c ->
    var bestIdx = -1
    var bestDist = Float.MAX_VALUE
    for (i in prev.indices) {
      if (used[i]) continue
      val p = prev[i]
      val d = hypot(
        (p.boundingBox.centerX() - c.boundingBox.centerX()).toDouble(),
        (p.boundingBox.centerY() - c.boundingBox.centerY()).toDouble(),
      ).toFloat()
      if (d < bestDist) {
        bestDist = d
        bestIdx = i
      }
    }
    if (bestIdx >= 0 && bestDist < c.boundingBox.width() * 1.5f) {
      used[bestIdx] = true
      prev[bestIdx]
    } else {
      null
    }
  }
}
