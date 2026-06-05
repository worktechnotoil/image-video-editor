package com.technotoil.image_videoeditor

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import java.io.File
import java.io.FileOutputStream

class FrameGrabberModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "RNFrameGrabber"

  @ReactMethod
  fun captureFrame(uriString: String, options: ReadableMap, promise: Promise) {
    try {
      val retriever = MediaMetadataRetriever()
      
      val uri = Uri.parse(uriString)
      if (uri.scheme == "file" || uriString.startsWith("/")) {
        val path = uri.path ?: if (uriString.startsWith("file://")) uriString.substring(7) else uriString
        retriever.setDataSource(path)
      } else {
        retriever.setDataSource(reactContext, uri)
      }

      val timeMs = if (options.hasKey("timeMs")) options.getDouble("timeMs") else 0.0
      val timeUs = (timeMs * 1000).toLong()
      
      var bitmap: Bitmap? = null
      try {
        bitmap = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
      } catch (e: Exception) {
        // Fallback
      }
      
      if (bitmap == null) {
        try {
          bitmap = retriever.getFrameAtTime(timeUs)
        } catch (e: Exception) {
          // Fallback
        }
      }
      
      retriever.release()

      if (bitmap == null) {
        promise.reject("frame_failed", "Could not capture frame")
        return
      }

      val outFile = File.createTempFile("frame_", ".jpg", reactContext.cacheDir)
      FileOutputStream(outFile).use { out ->
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
      }

      promise.resolve(Uri.fromFile(outFile).toString())
    } catch (e: Exception) {
      promise.reject("frame_failed", e.message, e)
    }
  }
}
