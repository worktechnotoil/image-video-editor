package com.technotoil.image_videoeditor.camerafilter

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.os.SystemClock
import android.util.AttributeSet
import android.util.Size
import android.view.View
import android.view.MotionEvent
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.findViewTreeLifecycleOwner
import androidx.lifecycle.findViewTreeLifecycleOwner
import java.util.concurrent.Executors
import com.facebook.react.bridge.Promise
import java.io.File

class CameraFilterView(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {

  companion object {
    @Volatile var activeInstance: CameraFilterView? = null
  }



  private var currentFilter: FilterId = FilterId.NONE
  private var frame: Bitmap? = null
  private var faceAnalyzer: FaceAnalyzer? = null

  private var drawingFrame: Bitmap? = null
  private var videoRecorder: FilterVideoRecorder? = null
  private var isRecording = false
  private var videoOutputFile: String? = null

  private fun updateFrame(newFrame: Bitmap) {
    var orphanedFrame: Bitmap? = null
    synchronized(faceLock) {
      val oldFrame = frame
      if (oldFrame != null && oldFrame !== newFrame && oldFrame !== drawingFrame) {
        orphanedFrame = oldFrame
      }
      frame = newFrame
    }
    orphanedFrame?.let { faceAnalyzer?.releaseDisplayBitmap(it) }
  }


  // Two most recent detection results, interpolated between in onDraw so overlays glide at
  // full video framerate instead of stepping every time a (slower) detection completes.
  private var prevFaces: List<DetectedFace> = emptyList()
  private var currFaces: List<DetectedFace> = emptyList()
  private var facesUpdatedAt: Long = 0L
  private var faceUpdateInterval: Long = 33L

  private val faceVelocities = mutableListOf<FaceVelocity>()
  private val faceLock = Any()

  private val mirrorMatrix = Matrix()
  private var cameraProvider: ProcessCameraProvider? = null
  private val analysisExecutor = Executors.newSingleThreadExecutor()
  private var facingStr: String = "front"

  fun setFacing(facing: String?) {
    val newFacing = facing ?: "front"
    if (this.facingStr != newFacing) {
      this.facingStr = newFacing
      if (cameraProvider != null) {
        startCamera()
      }
    }
  }

  // Lazy-loaded bow bitmap for the pookie bow filter
  private var bowBitmap: Bitmap? = null
  private fun getBowBitmap(): Bitmap {
    return bowBitmap ?: BitmapFactory.decodeResource(
      context.resources,
      context.resources.getIdentifier("bow_pookie", "drawable", context.packageName)
    ).also { bowBitmap = it }
  }

  // Lazy-loaded panda bitmap for the panda filter
  private var pandaBitmap: Bitmap? = null
  private fun getPandaBitmap(): Bitmap {
    return pandaBitmap ?: BitmapFactory.decodeResource(
      context.resources,
      context.resources.getIdentifier("panda_face", "drawable", context.packageName)
    ).also { pandaBitmap = it }
  }

  // Lazy-loaded skull bitmap for the retro skull filter
  private var skullBitmap: Bitmap? = null
  private fun getSkullBitmap(): Bitmap {
    return skullBitmap ?: BitmapFactory.decodeResource(
      context.resources,
      context.resources.getIdentifier("retro_skull", "drawable", context.packageName)
    ).also { skullBitmap = it }
  }

  // Lazy-loaded fashion background for the fashion overlay filter
  private var fashionBitmap: Bitmap? = null
  private fun getFashionBitmap(): Bitmap {
    return fashionBitmap ?: BitmapFactory.decodeResource(
      context.resources,
      context.resources.getIdentifier("fashion_girl", "drawable", context.packageName)
    ).also { fashionBitmap = it }
  }

  // Lazy-loaded talking forest background for the talking forest filter
  private var forestBitmap: Bitmap? = null
  private fun getForestBitmap(): Bitmap {
    return forestBitmap ?: BitmapFactory.decodeResource(
      context.resources,
      context.resources.getIdentifier("talking_forest", "drawable", context.packageName)
    ).also { forestBitmap = it }
  }

  fun setFilter(id: String) {
    currentFilter = FilterId.fromJs(id)
    invalidate()
  }

  fun startRecording(promise: Promise) {
    if (isRecording) {
      promise.reject("recording", "Already recording")
      return
    }
    isRecording = true
    
    val watchdogThread = kotlin.concurrent.thread {
        try {
            Thread.sleep(3000) // 3 seconds timeout
            if (isRecording && videoRecorder == null) {
                // If it's still trying to start after 3 seconds, it's hung!
                isRecording = false
                promise.reject("timeout", "Camera hardware froze during initialization")
            }
        } catch (e: InterruptedException) {}
    }

    kotlin.concurrent.thread {
      try {
        val outFile = File(context.cacheDir, "filter_video_${System.currentTimeMillis()}.mp4")
        videoOutputFile = outFile.absolutePath
        val newRecorder = FilterVideoRecorder(
          outputFile = outFile.absolutePath,
          width = 720,
          height = 1280,
          drawCallback = { canvas ->
              canvas.drawColor(android.graphics.Color.BLACK)
              val bitmap = synchronized(faceLock) { drawingFrame ?: frame } ?: return@FilterVideoRecorder
              val canvasW = canvas.width.toFloat()
              val canvasH = canvas.height.toFloat()
              val scale = maxOf(canvasW / bitmap.width, canvasH / bitmap.height)
              val dx = (canvasW - bitmap.width * scale) / 2f
              val dy = (canvasH - bitmap.height * scale) / 2f
              canvas.save()
              canvas.translate(dx, dy)
              canvas.scale(scale, scale)
              val recMirror = android.graphics.Matrix()
              if (facingStr == "front") {
                recMirror.setScale(-1f, 1f)
                recMirror.postTranslate(bitmap.width.toFloat(), 0f)
              }
              canvas.concat(recMirror)
              val faces = synchronized(faceLock) { currFaces }
              drawFrame(canvas, bitmap, faces)
              canvas.restore()
          }
        )
        newRecorder.start()
        watchdogThread.interrupt() // Cancel watchdog
        videoRecorder = newRecorder
        promise.resolve(null)
      } catch (e: Exception) {
        watchdogThread.interrupt()
        isRecording = false
        promise.reject("error", e.message)
      }
    }
  }

  fun stopRecording(promise: Promise) {
    if (!isRecording) {
      promise.reject("not_recording", "Not recording")
      return
    }
    isRecording = false
    val vr = videoRecorder
    videoRecorder = null
    kotlin.concurrent.thread {
      try {
        vr?.stop()
        if (videoOutputFile != null) {
          var durationMs = 0L
          val retriever = android.media.MediaMetadataRetriever()
          try {
            retriever.setDataSource(videoOutputFile)
            val durStr = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)
            durationMs = durStr?.toLongOrNull() ?: 0L
          } catch (_: Exception) {} finally {
            try { retriever.release() } catch (_: Exception) {}
          }
          val map = com.facebook.react.bridge.Arguments.createMap().apply {
            putString("uri", "file://$videoOutputFile")
            putDouble("durationMs", durationMs.toDouble())
            putInt("width", 720)
            putInt("height", 1280)
          }
          promise.resolve(map)
        } else {
          promise.resolve("success")
        }
      } catch (e: Exception) {
        promise.reject("error", e.message)
      }
    }
  }

  fun capturePhoto(promise: Promise) {
    var bitmap = drawingFrame ?: frame
    if (bitmap == null) {
      for (i in 0..10) {
        try { Thread.sleep(50) } catch (e: Exception) {}
        bitmap = drawingFrame ?: frame
        if (bitmap != null) break
      }
    }
    if (bitmap == null) {
      promise.reject("no_frame", "No camera frame available")
      return
    }
    val w = width.takeIf { it > 0 } ?: 720
    val h = height.takeIf { it > 0 } ?: 1280
    kotlin.concurrent.thread {
      try {
        val resultBitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(resultBitmap)
        
        val scale = maxOf(w.toFloat() / bitmap.width, h.toFloat() / bitmap.height)
        val dx = (w - bitmap.width * scale) / 2f
        val dy = (h - bitmap.height * scale) / 2f
        
        canvas.save()
        canvas.translate(dx, dy)
        canvas.scale(scale, scale)
        canvas.concat(mirrorMatrix)
        drawFrame(canvas, bitmap, currFaces)
        canvas.restore()

        val outFile = File(context.cacheDir, "filter_photo_${System.currentTimeMillis()}.jpg")
        outFile.outputStream().use { out ->
          resultBitmap.compress(Bitmap.CompressFormat.JPEG, 100, out)
        }
        promise.resolve("file://${outFile.absolutePath}")
      } catch (e: Exception) {
        promise.reject("error", e.message)
      }
    }
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    if (event.action == MotionEvent.ACTION_DOWN) {
      if (currentFilter == FilterId.SNAP_LENS_VERIFIED) {
        AROverlays.randomizeLensVerifiedCard()
        postInvalidate()
        return true
      }
    }
    return super.onTouchEvent(event)
  }


  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    activeInstance = this
    startCamera()
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    if (activeInstance == this) {
      activeInstance = null
    }
    cameraProvider?.unbindAll()
    cameraProvider = null
    analysisExecutor.shutdown()
    val analyzer = faceAnalyzer
    faceAnalyzer = null
    analyzer?.clearPools()
    synchronized(faceLock) {
      frame = null
    }
  }

  private fun startCamera() {
    val future = ProcessCameraProvider.getInstance(context)
    future.addListener({
      val provider = future.get()
      cameraProvider = provider

      // setTargetResolution() is a deprecated, best-effort hint that some camera HALs ignore
      // outright (observed on this device: it silently picked a 2736x2736 analysis stream,
      // ~8x the pixel count requested, tanking every downstream conversion/detection/draw
      // step). ResolutionSelector with a bounded ResolutionStrategy actually constrains the
      // chosen stream size instead of merely suggesting it.
      val resolutionSelector = ResolutionSelector.Builder()
        .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
        .setResolutionStrategy(
          ResolutionStrategy(Size(1280, 720), ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER),
        )
        .build()

      val analysis = ImageAnalysis.Builder()
        .setResolutionSelector(resolutionSelector)
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
        .build()

      val preview = androidx.camera.core.Preview.Builder()
        .setResolutionSelector(resolutionSelector)
        .build()
      preview.setSurfaceProvider { request ->
        val surfaceTexture = android.graphics.SurfaceTexture(0)
        surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
        val surface = android.view.Surface(surfaceTexture)
        request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
          surface.release()
          surfaceTexture.release()
        }
      }

      val analyzer = FaceAnalyzer { bitmap, detectedFaces, detectionTimestamp, rotationDegrees ->
        updateFrame(bitmap)
        synchronized(faceLock) {
          if (detectedFaces !== currFaces) {
            val dt = if (facesUpdatedAt != 0L) (detectionTimestamp - facesUpdatedAt).toFloat() else 0f
            if (dt > 0f) {
              updateVelocities(currFaces, detectedFaces, faceVelocities, dt)
            }
            if (facesUpdatedAt != 0L) {
              faceUpdateInterval = (detectionTimestamp - facesUpdatedAt).coerceIn(30L, 400L)
            }
            prevFaces = currFaces
            currFaces = detectedFaces
            facesUpdatedAt = detectionTimestamp
          }
        }
        if (isRecording) {
          videoRecorder?.onFrame()
        }
        postInvalidate()
      }
      faceAnalyzer?.clearPools()
      faceAnalyzer = analyzer
      analysis.setAnalyzer(analysisExecutor, analyzer)

      val activity = (context as? com.facebook.react.uimanager.ThemedReactContext)?.currentActivity as? androidx.lifecycle.LifecycleOwner
      val lifecycleOwner = this@CameraFilterView.findViewTreeLifecycleOwner() ?: activity ?: return@addListener
      provider.unbindAll()
      val cameraSelector = if (facingStr == "back") CameraSelector.DEFAULT_BACK_CAMERA else CameraSelector.DEFAULT_FRONT_CAMERA
      provider.bindToLifecycle(
        lifecycleOwner,
        cameraSelector,
        preview,
        analysis,
      )
    }, ContextCompat.getMainExecutor(context))
  }

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    val bitmap: Bitmap
    val oldDrawingFrame: Bitmap?
    val now = SystemClock.uptimeMillis()
    val faces: List<DetectedFace>
    synchronized(faceLock) {
      bitmap = frame ?: return
      oldDrawingFrame = drawingFrame
      drawingFrame = bitmap

      val elapsedMs = (now - facesUpdatedAt).toFloat()
      val intervalMs = faceUpdateInterval.toFloat()
      val t = elapsedMs / intervalMs
      faces = interpolateFaces(prevFaces, currFaces, t, faceVelocities, elapsedMs, intervalMs)
    }

    if (oldDrawingFrame != null && oldDrawingFrame !== bitmap) {
      faceAnalyzer?.releaseDisplayBitmap(oldDrawingFrame)
    }

    val scale = maxOf(width.toFloat() / bitmap.width, height.toFloat() / bitmap.height)
    val dx = (width - bitmap.width * scale) / 2f
    val dy = (height - bitmap.height * scale) / 2f

    canvas.save()
    canvas.translate(dx, dy)
    canvas.scale(scale, scale)

    // Front camera output isn't pre-mirrored; flip horizontally.
    mirrorMatrix.reset()
    if (facingStr == "front") {
      mirrorMatrix.setScale(-1f, 1f)
      mirrorMatrix.postTranslate(bitmap.width.toFloat(), 0f)
    }
    canvas.concat(mirrorMatrix)

    drawFrame(canvas, bitmap, faces)

    canvas.restore()
  }

  private fun drawFrame(canvas: Canvas, bitmap: Bitmap, faces: List<DetectedFace>) {
    AROverlays.isFrontCamera = (facingStr == "front")
    ColorFilters.isFrontCamera = (facingStr == "front")
    when (currentFilter) {
      FilterId.VINTAGE -> ColorFilters.applyVintage(canvas, bitmap)
      FilterId.BLACK_WHITE -> ColorFilters.applyBlackWhite(canvas, bitmap)
      FilterId.VIBRANT -> ColorFilters.applyVibrant(canvas, bitmap)
      FilterId.COOL_TONE -> ColorFilters.applyCoolTone(canvas, bitmap)
      FilterId.WARM_TONE -> ColorFilters.applyWarmTone(canvas, bitmap)

      FilterId.SNAP_BUTTERFLIES -> {
        ColorFilters.applyBlackWhite(canvas, bitmap)
        faces.forEach { AROverlays.drawButterflies(canvas, it) }
      }
      FilterId.SNAP_NEON_OUTLINE -> {
        ColorFilters.applyVibrant(canvas, bitmap)
        faces.forEach {
          BeautyFilters.drawSmoothSkin(canvas, bitmap, it)
          BeautyFilters.drawBrightenGlow(canvas, bitmap, it)
          AROverlays.drawNeonOutline(canvas, it)
        }
      }
      FilterId.SNAP_NEON_NEON -> {
        ColorFilters.applyCyberpunk(canvas, bitmap)
        faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.SPORT) }
      }
      FilterId.SNAP_SUNSET_COWBOY -> {
        ColorFilters.applySunset(canvas, bitmap)
        faces.forEach { AROverlays.drawHat(canvas, it, AROverlays.HatStyleType.COWBOY) }
      }
      FilterId.SNAP_ICY_DALMATIAN -> {
        ColorFilters.applyIce(canvas, bitmap)
        faces.forEach { AROverlays.drawDogEars(canvas, it, AROverlays.DogStyleType.DALMATIAN) }
      }
      FilterId.SNAP_RETRO_BLOOM -> {
        ColorFilters.applyRetroFilm(canvas, bitmap)
        faces.forEach { AROverlays.drawFlowerCrown(canvas, it, AROverlays.FlowerStyleType.GOLD) }
      }
      FilterId.SNAP_NOIR_KITTY -> {
        ColorFilters.applyBrightWhite(canvas, bitmap)
        faces.forEach {
          AROverlays.drawCatEars(canvas, it, AROverlays.CatStyleType.PINK)
        }
      }
      FilterId.SNAP_EVIL_BW -> {
        // Black & White camera feed
        ColorFilters.applyBlackWhite(canvas, bitmap)
        faces.forEach {
          // Red neon evil horns pop dramatically over the monochrome face
          AROverlays.drawEvilHorns(canvas, it)
        }
      }
      FilterId.SNAP_BOW_AESTHETIC -> {
        // Warm, bright, airy aesthetic pink color grade
        ColorFilters.applyAestheticPink(canvas, bitmap)
        faces.forEach {
          // Hot-pink hair bows
          AROverlays.drawPinkBows(canvas, it, getBowBitmap())
        }
      }
      FilterId.SNAP_DARK_MOON -> {
        // Very dark B&W camera tone
        ColorFilters.applyDarkMoon(canvas, bitmap)
        faces.forEach {
          // Golden crescent moons scattered across the face
          AROverlays.drawCrescentMoons(canvas, it)
        }
      }
      FilterId.SNAP_PINK_HEARTS -> {
        // Soft monochrome selfie with floating pink hearts, matching the reference vibe.
        ColorFilters.applyBlackWhite(canvas, bitmap)
        faces.forEach {
          AROverlays.drawPinkHearts(canvas, it)
        }
      }
      FilterId.SNAP_DAY_STAMP -> {
        // Warm daylight aesthetic with a date/time stamp like the reference image.
        ColorFilters.applyDayStamp(canvas, bitmap)
      }
      FilterId.SNAP_HEART_FRAME -> {
        AROverlays.drawHeartFrame(canvas, bitmap, faces)
      }
      FilterId.SNAP_CITY_TIME -> {
        AROverlays.drawCityTime(canvas, bitmap, faces)
      }
      FilterId.SNAP_POOKIE -> {
        ColorFilters.applyWarmTone(canvas, bitmap)
        faces.forEach {
          AROverlays.drawPookieBow(canvas, it, getBowBitmap())
        }
      }
      FilterId.SNAP_PANDA_FACE -> {
        ColorFilters.applyBlackWhite(canvas, bitmap)
        faces.forEach {
          AROverlays.drawPandaFaces(canvas, it, getPandaBitmap())
        }
      }
      FilterId.SNAP_VINTAGE_GRAIN -> {
        ColorFilters.applyVintageGrain(canvas, bitmap)
      }
      FilterId.SNAP_SPIDERMAN -> {
        ColorFilters.applyBlackWhite(canvas, bitmap)
        faces.forEach {
          AROverlays.drawSpidermanMask(canvas, it)
        }
      }
      FilterId.SNAP_EYES_REVEAL -> {
        AROverlays.drawEyesReveal(canvas, bitmap, faces.firstOrNull())
      }
      FilterId.SNAP_WANTED_POSTER -> {
        AROverlays.drawWantedPoster(canvas, bitmap)
      }
      FilterId.SNAP_PINK_FLOWER -> {
        ColorFilters.applyAestheticPink(canvas, bitmap)
        faces.forEach {
          AROverlays.drawPlumeriaFlower(canvas, it)
        }
      }
      FilterId.SNAP_RETRO_SKULL -> {
        ColorFilters.applyDarkMoon(canvas, bitmap)
        AROverlays.drawSkullFixed(canvas, bitmap, getSkullBitmap())
      }
      FilterId.SNAP_FASHION_OVERLAY -> {
        val canvasW = canvas.width.toFloat()
        val canvasH = canvas.height.toFloat()
        if (canvasW > 0f && canvasH > 0f) {
          // 1. Draw static background image (center-crop cover)
          val bg = getFashionBitmap()
          val bgW = bg.width.toFloat()
          val bgH = bg.height.toFloat()
          val bgScale = maxOf(canvasW / bgW, canvasH / bgH)
          val bgSrcW = canvasW / bgScale
          val bgSrcH = canvasH / bgScale
          val bgSrcX = (bgW - bgSrcW) / 2f
          val bgSrcY = (bgH - bgSrcH) / 2f
          val bgSrcRect = Rect(bgSrcX.toInt(), bgSrcY.toInt(), (bgSrcX + bgSrcW).toInt(), (bgSrcY + bgSrcH).toInt())
          val destRect = RectF(0f, 0f, canvasW, canvasH)
          canvas.drawBitmap(bg, bgSrcRect, destRect, null)

          // 2. Draw live camera feed on top with less opacity (alpha = 90 / 255)
          val frameW = bitmap.width.toFloat()
          val frameH = bitmap.height.toFloat()
          val frameScale = maxOf(canvasW / frameW, canvasH / frameH)
          val frameSrcW = canvasW / frameScale
          val frameSrcH = canvasH / frameScale
          val frameSrcX = (frameW - frameSrcW) / 2f
          val frameSrcY = (frameH - frameSrcH) / 2f
          val frameSrcRect = Rect(frameSrcX.toInt(), frameSrcY.toInt(), (frameSrcX + frameSrcW).toInt(), (frameSrcY + frameSrcH).toInt())
          
          val opacityPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            alpha = 90
          }
          canvas.drawBitmap(bitmap, frameSrcRect, destRect, opacityPaint)
        }
      }
      FilterId.SNAP_TALKING_FOREST -> {
        AROverlays.drawTalkingForest(canvas, bitmap, faces.firstOrNull(), getForestBitmap())
      }
      FilterId.SNAP_LENS_VERIFIED -> {
        // Draw the background feed
        canvas.drawBitmap(bitmap, 0f, 0f, null)
        // Apply skin smoothing and brightening glow to the user's face in the background
        faces.forEach {
          BeautyFilters.drawSmoothSkin(canvas, bitmap, it)
          BeautyFilters.drawBrightenGlow(canvas, bitmap, it)
        }
        // Draw the Lens+ Verified card overlay on top
        AROverlays.drawLensVerifiedCard(canvas, bitmap, faces.firstOrNull())
      }
      FilterId.SNAP_CREATOR_HUD -> {
        // Apply full-screen soft warm creamy glow color grading to the whole frame
        ColorFilters.applyCreamySoftGlow(canvas, bitmap)
      }

      FilterId.SNAP_CARTOON_TOON -> {
        // Illustrated / cartoon art-style: affects the whole frame (face + background)
        CartoonFilter.apply(canvas, bitmap)
      }

      FilterId.EYE_ENHANCE -> {
        val points = faces.flatMap { eyeEnhancePoints(it) }.take(MAX_CONTROL_POINTS)
        WarpEffects.apply(canvas, bitmap, points)
      }
      FilterId.SLIM_FACE -> {
        val points = faces.flatMap { slimFacePoints(it) }.take(MAX_CONTROL_POINTS)
        WarpEffects.apply(canvas, bitmap, points)
      }
      FilterId.FISHEYE_BULGE -> {
        val points = faces.flatMap { fisheyePoints(it) }.take(MAX_CONTROL_POINTS)
        WarpEffects.apply(canvas, bitmap, points)
      }
      FilterId.BABY_FACE -> {
        val points = faces.flatMap { babyFacePoints(it) }.take(MAX_CONTROL_POINTS)
        WarpEffects.apply(canvas, bitmap, points)
      }

      else -> {
        canvas.drawBitmap(bitmap, 0f, 0f, null)
        when (currentFilter) {
          FilterId.SMOOTH_SKIN -> faces.forEach { BeautyFilters.drawSmoothSkin(canvas, bitmap, it) }
          FilterId.BRIGHTEN_GLOW -> faces.forEach { BeautyFilters.drawBrightenGlow(canvas, bitmap, it) }
          FilterId.LIPSTICK -> faces.forEach { BeautyFilters.drawLipstick(canvas, it, "red") }
          FilterId.LIPSTICK_RED -> faces.forEach { BeautyFilters.drawLipstick(canvas, it, "red") }
          FilterId.LIPSTICK_PINK -> faces.forEach { BeautyFilters.drawLipstick(canvas, it, "pink") }
          FilterId.LIPSTICK_CORAL -> faces.forEach { BeautyFilters.drawLipstick(canvas, it, "coral") }
          FilterId.LIPSTICK_PLUM -> faces.forEach { BeautyFilters.drawLipstick(canvas, it, "plum") }
          FilterId.BIG_HEAD -> faces.forEach { Distortion.drawBigHead(canvas, bitmap, it) }
          FilterId.OLD_AGE -> faces.forEach { Distortion.drawOldAge(canvas, bitmap, it) }
          FilterId.DOG_EARS -> faces.forEach { AROverlays.drawDogEars(canvas, it) }
          FilterId.CAT_EARS -> faces.forEach { AROverlays.drawCatEars(canvas, it) }
          FilterId.FLOWER_CROWN -> faces.forEach { AROverlays.drawFlowerCrown(canvas, it) }
          FilterId.GLASSES -> faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.CLASSIC) }
          FilterId.GLASSES_CLASSIC -> faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.CLASSIC) }
          FilterId.GLASSES_SUN -> faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.SUN) }
          FilterId.GLASSES_RETRO -> faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.RETRO) }
          FilterId.GLASSES_HEART -> faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.HEART) }
          FilterId.GLASSES_SPORT -> faces.forEach { AROverlays.drawGlasses(canvas, it, AROverlays.GlassStyleType.SPORT) }
          FilterId.HAT -> faces.forEach { AROverlays.drawHat(canvas, it, AROverlays.HatStyleType.WIZARD) }
          FilterId.HAT_WIZARD -> faces.forEach { AROverlays.drawHat(canvas, it, AROverlays.HatStyleType.WIZARD) }
          FilterId.HAT_COWBOY -> faces.forEach { AROverlays.drawHat(canvas, it, AROverlays.HatStyleType.COWBOY) }
          FilterId.HAT_SANTA -> faces.forEach { AROverlays.drawHat(canvas, it, AROverlays.HatStyleType.SANTA) }
          FilterId.FACE_SWAP -> FaceSwap.draw(canvas, bitmap, faces)
          FilterId.NONE -> {}
          else -> {}
        }
      }
    }
  }
}
