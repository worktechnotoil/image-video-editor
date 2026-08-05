package com.technotoil.image_videoeditor.camerafilter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.os.SystemClock
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.nio.ByteBuffer
import java.nio.ByteOrder

private const val DETECTION_WIDTH = 240

class BitmapPool(val width: Int, val height: Int, val maxPoolSize: Int = 3) {
  private val pool = ArrayDeque<Bitmap>(maxPoolSize)

  @Synchronized
  fun acquire(): Bitmap {
    return if (pool.isNotEmpty()) {
      pool.removeFirst()
    } else {
      Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    }
  }

  @Synchronized
  fun release(bitmap: Bitmap) {
    if (bitmap.width == width && bitmap.height == height && pool.size < maxPoolSize + 2) {
      pool.addLast(bitmap)
    } else {
      bitmap.recycle()
    }
  }

  @Synchronized
  fun clear() {
    for (b in pool) {
      b.recycle()
    }
    pool.clear()
  }
}

class FaceAnalyzer(
  private val onResult: (Bitmap, List<DetectedFace>, Long, Int) -> Unit,
) : ImageAnalysis.Analyzer {

  private val detector = FaceDetection.getClient(
    FaceDetectorOptions.Builder()
      .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
      .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
      .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
      .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
      .build(),
  )

  @Volatile private var detecting = false
  @Volatile private var latestFaces: List<DetectedFace> = emptyList()
  @Volatile private var latestFacesTimestamp: Long = 0L

  @Volatile private var rawPool: BitmapPool? = null
  @Volatile private var displayPool: BitmapPool? = null
  @Volatile private var smallPool: BitmapPool? = null
  
  private var pixelBuffer: ByteBuffer? = null

  fun releaseDisplayBitmap(bitmap: Bitmap) {
    displayPool?.release(bitmap)
  }

  fun clearPools() {
    rawPool?.clear()
    rawPool = null
    displayPool?.clear()
    displayPool = null
    smallPool?.clear()
    smallPool = null
  }

  override fun analyze(imageProxy: ImageProxy) {
    if (imageProxy.image == null) {
      imageProxy.close()
      return
    }

    val rotationDegrees = imageProxy.imageInfo.rotationDegrees
    val w = imageProxy.width
    val h = imageProxy.height

    val uprightW = if (rotationDegrees == 90 || rotationDegrees == 270) h else w
    val uprightH = if (rotationDegrees == 90 || rotationDegrees == 270) w else h

    // Lazily initialize/recreate pools if dimensions change
    var rp = rawPool
    if (rp == null || rp.width != w || rp.height != h) {
      rp?.clear()
      rp = BitmapPool(w, h, 3)
      rawPool = rp
    }

    var dp = displayPool
    if (dp == null || dp.width != uprightW || dp.height != uprightH) {
      dp?.clear()
      dp = BitmapPool(uprightW, uprightH, 3)
      displayPool = dp
    }

    // 1. Copy YUV/RGBA bytes to rawBitmap using fast direct ByteBuffer memcpy
    val rawBitmap = rp.acquire()
    val plane = imageProxy.planes[0]
    val buffer = plane.buffer
    val rowStride = plane.rowStride
    val rowWidthBytes = w * 4

    val totalBytes = w * h * 4
    var pb = pixelBuffer
    if (pb == null || pb.capacity() < totalBytes) {
      pb = ByteBuffer.allocateDirect(totalBytes).order(ByteOrder.nativeOrder())
      pixelBuffer = pb
    }
    pb.rewind()

    buffer.rewind()
    if (rowStride == rowWidthBytes) {
      pb.put(buffer)
    } else {
      val oldLimit = buffer.limit()
      for (y in 0 until h) {
        buffer.position(y * rowStride)
        buffer.limit(buffer.position() + rowWidthBytes)
        pb.put(buffer)
      }
      buffer.limit(oldLimit)
    }
    pb.rewind()
    rawBitmap.copyPixelsFromBuffer(pb)

    // 2. Perform rotation using Canvas drawing on background thread
    val displayBitmap = dp.acquire()
    val canvas = Canvas(displayBitmap)
    val matrix = Matrix()
    matrix.postRotate(rotationDegrees.toFloat())
    when (rotationDegrees) {
      90 -> matrix.postTranslate(h.toFloat(), 0f)
      180 -> matrix.postTranslate(w.toFloat(), h.toFloat())
      270 -> matrix.postTranslate(0f, w.toFloat())
    }
    canvas.drawBitmap(rawBitmap, matrix, null)
    
    // Release raw frame bitmap back to the pool
    rp.release(rawBitmap)

    // Close the image proxy immediately to unblock camera analysis pipeline
    imageProxy.close()

    // 3. Dispatch the display frame to the UI view
    onResult(displayBitmap, latestFaces, latestFacesTimestamp, rotationDegrees)

    // 4. Run face detection asynchronously if idle
    if (!detecting) {
      detecting = true
      val detectionTimestamp = SystemClock.uptimeMillis()
      val detectionScale = DETECTION_WIDTH.toFloat() / uprightW
      val detectionHeight = (uprightH * detectionScale).toInt().coerceAtLeast(1)

      var smPool = smallPool
      if (smPool == null || smPool.width != DETECTION_WIDTH || smPool.height != detectionHeight) {
        smPool?.clear()
        smPool = BitmapPool(DETECTION_WIDTH, detectionHeight, 3)
        smallPool = smPool
      }

      val small = smPool.acquire()
      val smallCanvas = Canvas(small)
      val scaleMatrix = Matrix()
      scaleMatrix.postScale(detectionScale, detectionScale)
      smallCanvas.drawBitmap(displayBitmap, scaleMatrix, null)

      val inputImage = InputImage.fromBitmap(small, 0)
      val upscale = 1f / detectionScale

      detector.process(inputImage)
        .addOnSuccessListener { faces ->
          latestFaces = faces.map { toDetectedFace(it, upscale) }
            .filter { it.leftEye != null && it.rightEye != null && !it.faceContour.isNullOrEmpty() }
          latestFacesTimestamp = detectionTimestamp
        }
        .addOnCompleteListener {
          detecting = false
          smPool.release(small)
        }
    }
  }
}
