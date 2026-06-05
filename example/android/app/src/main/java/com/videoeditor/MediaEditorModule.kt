package com.videoeditor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MediaEditorModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "RNMediaEditor"

  private fun cleanUri(uriString: String): Uri {
    val uri = Uri.parse(uriString)
    if (uri.scheme == "file") {
      val path = uri.path
      // Strip query parameters for local files as they break some native APIs
      return if (path != null) Uri.fromFile(File(path)) else uri
    }
    return uri
  }

  private fun downloadToCache(urlString: String): File {
    val url = java.net.URL(urlString)
    val connection = url.openConnection()
    connection.connect()
    val cacheFile = File.createTempFile("music_", ".mp3", reactContext.cacheDir)
    url.openStream().use { input ->
      FileOutputStream(cacheFile).use { output ->
        input.copyTo(output)
      }
    }
    return cacheFile
  }


  @ReactMethod
  fun editImage(uriString: String, options: ReadableMap, promise: Promise) {
    try {
      val uri = cleanUri(uriString)
      val input = reactContext.contentResolver.openInputStream(uri)
      val original = BitmapFactory.decodeStream(input)
      input?.close()

      if (original == null) {
        promise.reject("decode_failed", "Could not decode image")
        return
      }

      var bitmap = original
      try {
        val exifInput = reactContext.contentResolver.openInputStream(uri)
        if (exifInput != null) {
          val exif = android.media.ExifInterface(exifInput)
          val orientation = exif.getAttributeInt(
            android.media.ExifInterface.TAG_ORIENTATION,
            android.media.ExifInterface.ORIENTATION_NORMAL
          )
          exifInput.close()
          
          val exMatrix = Matrix()
          when (orientation) {
            android.media.ExifInterface.ORIENTATION_ROTATE_90 -> exMatrix.postRotate(90f)
            android.media.ExifInterface.ORIENTATION_ROTATE_180 -> exMatrix.postRotate(180f)
            android.media.ExifInterface.ORIENTATION_ROTATE_270 -> exMatrix.postRotate(270f)
            android.media.ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> exMatrix.postScale(-1f, 1f)
            android.media.ExifInterface.ORIENTATION_FLIP_VERTICAL -> exMatrix.postScale(1f, -1f)
          }
          if (!exMatrix.isIdentity) {
            bitmap = Bitmap.createBitmap(original, 0, 0, original.width, original.height, exMatrix, true)
          }
        }
      } catch (e: Exception) {
         // ignore exif failure
      }

      val rotateDegrees = if (options.hasKey("rotateDegrees")) options.getInt("rotateDegrees") else 0
      val flipX = options.hasKey("flipX") && options.getBoolean("flipX")
      val flipY = options.hasKey("flipY") && options.getBoolean("flipY")
      val brightness = if (options.hasKey("brightness")) options.getDouble("brightness").toFloat() else 0f
      val contrast = if (options.hasKey("contrast")) options.getDouble("contrast").toFloat() else 1f
      val saturation = if (options.hasKey("saturation")) options.getDouble("saturation").toFloat() else 1f
      val grayscale = options.hasKey("grayscale") && options.getBoolean("grayscale")
      val overlays = if (options.hasKey("overlays")) options.getArray("overlays") else null
      val effect = if (options.hasKey("effect")) options.getString("effect") else null

      val matrix = Matrix()
      if (flipX) matrix.postScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
      if (flipY) matrix.postScale(1f, -1f, bitmap.width / 2f, bitmap.height / 2f)
      if (rotateDegrees != 0) matrix.postRotate(rotateDegrees.toFloat(), bitmap.width / 2f, bitmap.height / 2f)

      if (!matrix.isIdentity) {
        bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
      }

      var outBitmap = bitmap
      if (options.hasKey("crop")) {
        val crop = options.getMap("crop")
        if (crop != null) {
          val cw = crop.getInt("width")
          val ch = crop.getInt("height")
          val cx = crop.getInt("x")
          val cy = crop.getInt("y")
          
          outBitmap = Bitmap.createBitmap(cw, ch, Bitmap.Config.ARGB_8888)
          val canvas = Canvas(outBitmap)
          canvas.drawColor(android.graphics.Color.BLACK)
          // Draw the bitmap relative to the crop origin.
          // If we want to crop at (50, 50), we draw at (-50, -50).
          canvas.drawBitmap(bitmap, (-cx).toFloat(), (-cy).toFloat(), null)
        }
      }

      val baseImage = if (outBitmap.isMutable) outBitmap else outBitmap.copy(Bitmap.Config.ARGB_8888, true)
      val baseCanvas = Canvas(baseImage)
      
      val rawFrameKey = if (options.hasKey("frame")) options.getString("frame") else null
      val hasFrame = !rawFrameKey.isNullOrEmpty()
      
      if (hasFrame) {
        val insetScale = if (options.hasKey("frameScale")) options.getDouble("frameScale").toFloat() else 0.88f
        val offsetYRatio = if (options.hasKey("frameOffsetY")) options.getDouble("frameOffsetY").toFloat() else 0.0f
        
        // Fill with opaque black first so JPEG compression doesn't produce
        // garbage in the transparent padding areas around the inset photo.
        baseCanvas.drawColor(android.graphics.Color.BLACK)
        
        val insetW = outBitmap.width * insetScale
        val insetH = outBitmap.height * insetScale
        val tx = (outBitmap.width - insetW) / 2f
        val ty = (outBitmap.height - insetH) / 2f
        val extraTY = outBitmap.height * offsetYRatio
        
        val destRect = RectF(tx, ty + extraTY, tx + insetW, ty + extraTY + insetH)
        baseCanvas.drawBitmap(outBitmap, null, destRect, null)
      } else {
        baseCanvas.drawBitmap(outBitmap, 0f, 0f, null)
      }

      // Frame drawing
      if (hasFrame) {
        try {
          val assetManager = reactContext.assets
          val inputStream = assetManager.open("frames/$rawFrameKey.png")
          val frameBitmap = BitmapFactory.decodeStream(inputStream)
          inputStream.close()
          
          if (frameBitmap != null) {
            android.util.Log.d("RNMediaEditor", "Frame loaded: $rawFrameKey  ${frameBitmap.width}x${frameBitmap.height}")
            val destRect = Rect(0, 0, baseImage.width, baseImage.height)
            baseCanvas.drawBitmap(frameBitmap, null, destRect, null)
            frameBitmap.recycle()
          } else {
            android.util.Log.w("RNMediaEditor", "Frame bitmap decode returned null for: $rawFrameKey")
          }
        } catch (e: Exception) {
          android.util.Log.e("RNMediaEditor", "Frame load FAILED for: $rawFrameKey — ${e.message}", e)
        }
      }

      val colorMatrix = ColorMatrix()
      
      // 1. Saturation
      if (grayscale) {
        colorMatrix.setSaturation(0f)
      } else {
        colorMatrix.setSaturation(saturation)
      }

      // 2. Contrast & Brightness
      // Contrast: c * x + (1-c)*128
      // Brightness: x + b*255
      val c = contrast
      val b = brightness * 255f
      val off = (1f - c) * 128f + b
      
      val m = floatArrayOf(
        c, 0f, 0f, 0f, off,
        0f, c, 0f, 0f, off,
        0f, 0f, c, 0f, off,
        0f, 0f, 0f, 1f, 0f
      )
      val temp = ColorMatrix(m)
      colorMatrix.postConcat(temp)

      val finalBitmap = Bitmap.createBitmap(baseImage.width, baseImage.height, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(finalBitmap)
      val paint = android.graphics.Paint().apply {
        isAntiAlias = true
        colorFilter = ColorMatrixColorFilter(colorMatrix)
      }
      canvas.drawBitmap(baseImage, 0f, 0f, paint)

      val overlayPaint = android.graphics.Paint().apply { isAntiAlias = true }

      // Tint color UI replica
      if (options.hasKey("tintColor") && options.hasKey("tintOpacity")) {
        val tintHex = options.getString("tintColor")
        val tintOp = options.getDouble("tintOpacity").toFloat()
        if (tintHex != null && tintOp > 0f) {
          overlayPaint.color = parseColorSafe(tintHex)
          overlayPaint.alpha = (tintOp * 255).toInt()
          canvas.drawRect(0f, 0f, finalBitmap.width.toFloat(), finalBitmap.height.toFloat(), overlayPaint)
        }
      }

      overlays?.toArrayList()?.forEach { anyOverlay ->
        val o = anyOverlay as? Map<*, *> ?: return@forEach
        val text = o["text"] as? String ?: return@forEach
        val x = (o["x"] as? Double ?: 0.0).toFloat()
        val y = (o["y"] as? Double ?: 0.0).toFloat()
        val color = (o["color"] as? String)?.let { parseColorSafe(it) } ?: android.graphics.Color.WHITE
        val fontSize = (o["fontSize"] as? Double ?: 16.0).toFloat()
        val textPaint = android.graphics.Paint().apply {
          this.color = color
          this.textSize = fontSize
          this.isAntiAlias = true
          this.typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        canvas.drawText(text, x, y, textPaint)
      }

      // Special Effects for Images
      if (!effect.isNullOrEmpty()) {
        when (effect) {
          "vignette" -> {
            val radius = Math.sqrt(Math.pow(finalBitmap.width.toDouble(), 2.0) + Math.pow(finalBitmap.height.toDouble(), 2.0)).toFloat() / 1.2f
            val gradient = android.graphics.RadialGradient(
              finalBitmap.width / 2f, finalBitmap.height / 2f, radius,
              intArrayOf(android.graphics.Color.TRANSPARENT, android.graphics.Color.BLACK),
              floatArrayOf(0.5f, 1.0f),
              android.graphics.Shader.TileMode.CLAMP
            )
            val vPaint = android.graphics.Paint()
            vPaint.shader = gradient
            vPaint.alpha = 180
            canvas.drawRect(0f, 0f, finalBitmap.width.toFloat(), finalBitmap.height.toFloat(), vPaint)
          }
          "pixelize" -> {
            // Simple pixelation via scaling
            val pxScale = 10
            val small = Bitmap.createScaledBitmap(finalBitmap, finalBitmap.width / pxScale, finalBitmap.height / pxScale, false)
            val pixelated = Bitmap.createScaledBitmap(small, finalBitmap.width, finalBitmap.height, false)
            canvas.drawBitmap(pixelated, 0f, 0f, null)
            small.recycle()
            pixelated.recycle()
          }
        }
      }

      val editedDir = File(reactContext.filesDir, "edited_media")
      if (!editedDir.exists()) editedDir.mkdirs()
      val outFile = File.createTempFile("edited_", ".jpg", editedDir)
      FileOutputStream(outFile).use { out ->
        finalBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
      }

      promise.resolve(Uri.fromFile(outFile).toString())
    } catch (e: Exception) {
      promise.reject("edit_failed", e.message, e)
    }
  }

  private fun parseColorSafe(hex: String): Int {
    return try { android.graphics.Color.parseColor(hex) } catch (e: Exception) { android.graphics.Color.WHITE }
  }

  @ReactMethod
  fun trimVideo(uriString: String, options: ReadableMap, promise: Promise) {
    try {
      val uri = cleanUri(uriString)
      val inputFile = MediaFileUtils.copyToCache(reactContext, uri, "trim")

      val isImage = options.hasKey("isImage") && options.getBoolean("isImage")
      val startMs = if (options.hasKey("startMs")) options.getDouble("startMs") else 0.0
      val endMs = if (options.hasKey("endMs")) options.getDouble("endMs") else 10000.0
      val durationMs = if (isImage) 10000.0 else Math.max(0.0, endMs - startMs)
      val mute = options.hasKey("mute") && options.getBoolean("mute")

      val rotateDegrees = if (options.hasKey("rotateDegrees")) options.getInt("rotateDegrees") else 0
      val flipX = options.hasKey("flipX") && options.getBoolean("flipX")
      val flipY = options.hasKey("flipY") && options.getBoolean("flipY")
      val brightness = if (options.hasKey("brightness")) options.getDouble("brightness") else 0.0
      val contrast = if (options.hasKey("contrast")) options.getDouble("contrast") else 1.0
      val saturation = if (options.hasKey("saturation")) options.getDouble("saturation") else 1.0
      val grayscale = options.hasKey("grayscale") && options.getBoolean("grayscale")

      val tintColor = if (options.hasKey("tintColor")) options.getString("tintColor") else null
      val tintOpacity = if (options.hasKey("tintOpacity")) options.getDouble("tintOpacity") else 0.0

      val crop = if (options.hasKey("crop")) options.getMap("crop") else null
      val hasCrop = crop != null && crop.hasKey("width") && crop.hasKey("height")

      val frameKey = if (options.hasKey("frame")) options.getString("frame") else null
      val hasFrame = !frameKey.isNullOrEmpty()
      val frameScale = if (options.hasKey("frameScale")) options.getDouble("frameScale") else 0.88
      val frameOffsetY = if (options.hasKey("frameOffsetY")) options.getDouble("frameOffsetY") else 0.0
      val effect = if (options.hasKey("effect")) options.getString("effect") else null

      val musicUri = if (options.hasKey("musicUri")) options.getString("musicUri") else null
      val hasMusic = !musicUri.isNullOrEmpty()

      val editedDir = File(reactContext.filesDir, "edited_media")
      if (!editedDir.exists()) editedDir.mkdirs()
      val outFile = File.createTempFile("edited_video_", ".mp4", editedDir)

      // Copy frame png from assets into a real file for ffmpeg input
      var frameFile: File? = null
      if (hasFrame) {
        frameFile = File(reactContext.cacheDir, "frame_${frameKey}_${System.currentTimeMillis()}.png")
        reactContext.assets.open("frames/${frameKey}.png").use { input ->
          FileOutputStream(frameFile).use { output ->
            input.copyTo(output)
          }
        }
      }

      // Download/copy music file
      var musicFile: File? = null
      if (hasMusic) {
        try {
          musicFile = if (musicUri!!.startsWith("http://") || musicUri.startsWith("https://")) {
            downloadToCache(musicUri)
          } else {
            MediaFileUtils.copyToCache(reactContext, Uri.parse(musicUri), "music")
          }
        } catch (e: Exception) {
          android.util.Log.e("RNMediaEditor", "Failed to download/copy music: ${e.message}")
        }
      }

      fun f(d: Double): String = String.format(Locale.US, "%.4f", d)
      fun escapePath(path: String): String = path.replace("\"", "\\\"")

      val filterSteps = mutableListOf<String>()
      var currentLabel = "[0:v]"

      // Transform: rotate (multiples of 90) + flips
      val xform = mutableListOf<String>()
      when ((rotateDegrees % 360 + 360) % 360) {
        90 -> xform.add("transpose=1")
        180 -> { xform.add("hflip"); xform.add("vflip") }
        270 -> xform.add("transpose=2")
      }
      if (flipX) xform.add("hflip")
      if (flipY) xform.add("vflip")
      if (xform.isNotEmpty()) {
        filterSteps.add("$currentLabel${xform.joinToString(",")}[v1]")
        currentLabel = "[v1]"
      }

      // Crop
      if (hasCrop) {
        val cx = crop!!.getInt("x")
        val cy = crop.getInt("y")
        val cw = crop.getInt("width")
        val ch = crop.getInt("height")
        filterSteps.add("$currentLabel" + "crop=${cw}:${ch}:${cx}:${cy}[v2]")
        currentLabel = "[v2]"
      }

      // 3. Frame overlay (scale down video content slightly, then draw frame png on top)
      if (hasFrame && frameFile != null) {
        val insetLabel = f(frameScale.coerceIn(0.1, 1.0))
        val oy = f(frameOffsetY)
        val vScale = "$currentLabel" + "scale=iw*${insetLabel}:ih*${insetLabel},pad=iw/${insetLabel}:ih/${insetLabel}:(ow-iw)/2:(oh-ih)/2+(${oy}*oh):color=black[v_scaled]"
        filterSteps.add(vScale)
        filterSteps.add("[1:v][v_scaled]scale2ref=w=iw:h=ih[frame_ref][v_padded]")
        filterSteps.add("[v_padded][frame_ref]overlay=0:0:format=auto[v_framed]")
        currentLabel = "[v_framed]"
      }

      // 4. Color adjustments (Apply after frame so the frame is also affected)
      val colorFilters = mutableListOf<String>()
      if (Math.abs(brightness) > 0.0001 || Math.abs(contrast - 1.0) > 0.0001 || Math.abs(saturation - 1.0) > 0.0001) {
        colorFilters.add("eq=brightness=${f(brightness)}:contrast=${f(contrast)}:saturation=${f(saturation)}")
      }
      if (grayscale) {
        colorFilters.add("hue=s=0")
      }
      if (colorFilters.isNotEmpty()) {
        filterSteps.add("$currentLabel${colorFilters.joinToString(",")}[v_colored]")
        currentLabel = "[v_colored]"
      }

      // 5. Tint overlay
      val shouldTint = !tintColor.isNullOrEmpty() && tintOpacity > 0.001
      if (shouldTint) {
        val safeTint = tintColor!!.trim()
        filterSteps.add("color=c=${safeTint}@${f(tintOpacity)}:size=2x2[tc]")
        filterSteps.add("[tc]$currentLabel" + "scale2ref=w=iw:h=ih[tc2][v_tint_base]")
        filterSteps.add("[v_tint_base][tc2]overlay=0:0:format=auto[v_tinted]")
        currentLabel = "[v_tinted]"
      }

      // 6. Special Effects
      if (!effect.isNullOrEmpty()) {
        when (effect) {
          "vignette" -> {
            filterSteps.add("$currentLabel" + "vignette=PI/4[v_effect]")
            currentLabel = "[v_effect]"
          }
          "pixelize" -> {
            filterSteps.add("$currentLabel" + "scale=iw/10:ih/10,scale=iw*10:ih*10:flags=neighbor[v_effect]")
            currentLabel = "[v_effect]"
          }
          "grain" -> {
            filterSteps.add("$currentLabel" + "noise=alls=15:allf=t+u[v_effect]")
            currentLabel = "[v_effect]"
          }
        }
      }

      // Final output label assignment - ensure even dimensions for the encoder
      if (currentLabel != "[vout]") {
        filterSteps.add("${currentLabel}scale=trunc(iw/2)*2:trunc(ih/2)*2[vout]")
        currentLabel = "[vout]"
      }

      // Audio configuration
      var hasVideoAudio = false
      if (!isImage) {
        try {
          val retriever = MediaMetadataRetriever()
          retriever.setDataSource(reactContext, uri)
          val hasAudioStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
          hasVideoAudio = "yes" == hasAudioStr
          retriever.release()
        } catch (e: Exception) {
          // ignore
        }
      }

      val musicInputIndex = if (hasFrame) 2 else 1

      val audioArgsList = if (hasMusic && musicFile != null) {
        if (hasVideoAudio && !mute) {
          // Mix audio tracks: [0:a] and [$musicInputIndex:a]
          filterSteps.add("[0:a]volume=1.0[a0];[$musicInputIndex:a]volume=0.8[a1];[a0][a1]amix=inputs=2:duration=first:dropout_transition=2[aout]")
          listOf("-map", "[aout]", "-c:a", "aac", "-b:a", "128k")
        } else {
          // Only map music track
          listOf("-map", "$musicInputIndex:a", "-c:a", "aac", "-b:a", "128k")
        }
      } else {
        if (mute) {
          listOf("-an")
        } else {
          listOf("-map", "0:a?", "-c:a", "aac", "-b:a", "128k")
        }
      }

      val filterComplex = filterSteps.joinToString(";")

      val ss = (startMs / 1000.0).coerceAtLeast(0.0)
      val tt = (durationMs / 1000.0).coerceAtLeast(0.0)
      val ssString = f(ss)
      val ttString = f(tt)

      val cmdList = mutableListOf("-y")
      
      if (isImage) {
        // Loop the input image for the duration of the output video
        cmdList.add("-loop")
        cmdList.add("1")
        cmdList.add("-t")
        cmdList.add(ttString)
        cmdList.add("-i")
        cmdList.add(inputFile.absolutePath)
      } else {
        // Fast seek on input
        cmdList.add("-ss")
        cmdList.add(ssString)
        cmdList.add("-i")
        cmdList.add(inputFile.absolutePath)
        cmdList.add("-t")
        cmdList.add(ttString)
      }
      
      if (frameFile != null) {
        cmdList.add("-i")
        cmdList.add(frameFile.absolutePath)
      }

      if (hasMusic && musicFile != null) {
        cmdList.add("-i")
        cmdList.add(musicFile.absolutePath)
      }

      cmdList.add("-filter_complex")
      cmdList.add(filterComplex)
      cmdList.add("-map")
      cmdList.add("[vout]")
      cmdList.addAll(audioArgsList)
      
      // Use h264_mediacodec for hardware acceleration on Android.
      // This is efficient and works well with minimal builds.
      cmdList.add("-c:v")
      cmdList.add("h264_mediacodec")
      cmdList.add("-b:v")
      cmdList.add("5M")
      cmdList.add("-pix_fmt")
      cmdList.add("yuv420p") // Wide compatibility
      cmdList.add(outFile.absolutePath)

      val cmdArray = cmdList.toTypedArray()
      android.util.Log.d("RNMediaEditor", "FFmpeg CMD: ${cmdList.joinToString(" ")}")
      
      FFmpegKit.executeWithArgumentsAsync(cmdArray) { session ->
        try {
          if (inputFile.exists()) inputFile.delete()
          frameFile?.let { try { if (it.exists()) it.delete() } catch (_: Exception) {} }
          musicFile?.let { try { if (it.exists()) it.delete() } catch (_: Exception) {} }
          val rc = session.returnCode
          if (ReturnCode.isSuccess(rc)) {
            promise.resolve(Uri.fromFile(outFile).toString())
          } else {
            val logs = session.allLogsAsString ?: "FFmpeg failed"
            promise.reject("trim_failed", logs)
          }
        } catch (e: Exception) {
          promise.reject("trim_failed", e.message, e)
        }
      }
    } catch (e: Exception) {
      promise.reject("trim_failed", e.message, e)
    }
  }

}
