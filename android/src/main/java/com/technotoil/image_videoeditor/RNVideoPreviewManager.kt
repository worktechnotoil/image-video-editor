package com.technotoil.image_videoeditor

import android.net.Uri
import android.widget.FrameLayout
import android.widget.VideoView
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.RCTEventEmitter

import android.view.TextureView
import android.graphics.SurfaceTexture
import android.view.Surface

class RNVideoView(context: android.content.Context) : FrameLayout(context), TextureView.SurfaceTextureListener {
    val textureView = TextureView(context)
    var uri: String? = null
    var isPaused: Boolean = false
    var isMuted: Boolean = true
    var mediaPlayer: android.media.MediaPlayer? = null
    var trimStartMs: Int = 0
    var trimEndMs: Int = 0
    var lastEmittedTime: Int = -1
    var isSeeking: Boolean = false
    var resizeMode: String = "cover"
    var videoW: Int = 0
    var videoH: Int = 0
    var mSurface: Surface? = null

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private val checkProgressRunnable = object : Runnable {
        override fun run() {
            try {
                if (mediaPlayer?.isPlaying == true) {
                    val current = mediaPlayer!!.currentPosition
                    if (trimEndMs > 0 && current >= trimEndMs) {
                        if (!isSeeking) {
                            isSeeking = true
                            mediaPlayer!!.seekTo(trimStartMs)
                        }
                    } else if (current < trimStartMs) {
                        if (!isSeeking) {
                            isSeeking = true
                            mediaPlayer!!.seekTo(trimStartMs)
                        }
                    } else {
                        isSeeking = false
                    }

                    if (id != android.view.View.NO_ID && current != lastEmittedTime) {
                        lastEmittedTime = current
                        val event = com.facebook.react.bridge.Arguments.createMap().apply {
                            putInt("currentTimeMs", current)
                        }
                        val reactContext = context as? com.facebook.react.bridge.ReactContext
                        if (reactContext != null) {
                                try {
                                    reactContext.getJSModule(com.facebook.react.uimanager.events.RCTEventEmitter::class.java)
                                        ?.receiveEvent(id, "topChange", event)
                                } catch (e: Exception) {}
                        }
                    }
                }
            } catch (e: Exception) {}
            mainHandler.postDelayed(this, 100)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        mainHandler.post(checkProgressRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        mainHandler.removeCallbacks(checkProgressRunnable)
        releasePlayer()
    }

    private val mLayoutRunnable = Runnable {
        measure(
            MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
        )
        layout(left, top, right, bottom)
    }

    override fun requestLayout() {
        super.requestLayout()
        post(mLayoutRunnable)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        
        val parentWidth = measuredWidth
        val parentHeight = measuredHeight
        
        if (videoW > 0 && videoH > 0 && parentWidth > 0 && parentHeight > 0) {
            val videoAspect = videoW.toFloat() / videoH.toFloat()
            val parentAspect = parentWidth.toFloat() / parentHeight.toFloat()
            
            var childWidth = parentWidth
            var childHeight = parentHeight
            
            if (resizeMode == "contain") {
                if (videoAspect > parentAspect) {
                    childHeight = (parentWidth / videoAspect).toInt()
                } else {
                    childWidth = (parentHeight * videoAspect).toInt()
                }
            } else {
                if (videoAspect > parentAspect) {
                    childWidth = (parentHeight * videoAspect).toInt()
                    childHeight = parentHeight
                } else {
                    childWidth = parentWidth
                    childHeight = (parentWidth / videoAspect).toInt()
                }
            }
            
            textureView.measure(
                MeasureSpec.makeMeasureSpec(childWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(childHeight, MeasureSpec.EXACTLY)
            )
        } else {
            textureView.measure(widthMeasureSpec, heightMeasureSpec)
        }
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val parentWidth = right - left
        val parentHeight = bottom - top
        
        val childWidth = textureView.measuredWidth
        val childHeight = textureView.measuredHeight
        
        val childLeft = (parentWidth - childWidth) / 2
        val childTop = (parentHeight - childHeight) / 2
        
        textureView.layout(childLeft, childTop, childLeft + childWidth, childTop + childHeight)
    }

    init {
        clipChildren = true
        textureView.surfaceTextureListener = this
        val lp = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, android.view.Gravity.CENTER)
        addView(textureView, lp)
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        mSurface = Surface(surface)
        preparePlayer()
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        mSurface?.release()
        mSurface = null
        releasePlayer()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}

    fun preparePlayer() {
        if (uri.isNullOrEmpty() || mSurface == null) return
        releasePlayer()
        try {
            mediaPlayer = android.media.MediaPlayer().apply {
                setSurface(mSurface)
                val parsedUri = Uri.parse(uri)
                if (parsedUri.scheme == "file" || uri!!.startsWith("/")) {
                    val path = parsedUri.path ?: if (uri!!.startsWith("file://")) uri!!.substring(7) else uri!!
                    setDataSource(path)
                } else {
                    setDataSource(context, parsedUri)
                }
                isLooping = true
                val volume = if (isMuted) 0f else 1f
                setVolume(volume, volume)
                
                setOnPreparedListener { mp ->
                    videoW = mp.videoWidth
                    videoH = mp.videoHeight
                    requestLayout()
                    if (trimStartMs > 0) {
                        mp.seekTo(trimStartMs)
                    }
                    if (!isPaused) {
                        mp.start()
                    }
                }
                setOnCompletionListener { mp ->
                    mp.seekTo(trimStartMs)
                    mp.start()
                }
                setOnErrorListener { _, _, _ -> true }
                prepareAsync()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun releasePlayer() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (e: Exception) {}
        mediaPlayer = null
    }

    fun updateVolume() {
        try {
            val volume = if (isMuted) 0f else 1f
            mediaPlayer?.setVolume(volume, volume)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

class RNVideoPreviewManager(private val reactContext: ReactApplicationContext) :
  SimpleViewManager<RNVideoView>() {

  override fun getName(): String = "RNVideoPreview"

  override fun createViewInstance(reactContext: ThemedReactContext): RNVideoView {
    return RNVideoView(reactContext)
  }

  override fun getExportedCustomBubblingEventTypeConstants(): Map<String, Any>? {
    return com.facebook.react.common.MapBuilder.builder<String, Any>()
      .put("topChange", com.facebook.react.common.MapBuilder.of(
          "phasedRegistrationNames", com.facebook.react.common.MapBuilder.of("bubbled", "onChange")
      ))
      .build()
  }

  @ReactProp(name = "uri")
  fun setUri(view: RNVideoView, uri: String?) {
    if (uri == view.uri) return
    view.uri = uri
    if (uri.isNullOrEmpty()) {
      view.releasePlayer()
      return
    }
    view.preparePlayer()
  }

  @ReactProp(name = "paused")
  fun setPaused(view: RNVideoView, paused: Boolean) {
    view.isPaused = paused
    if (paused) {
      try { view.mediaPlayer?.pause() } catch (e: Exception) {}
    } else {
      try { view.mediaPlayer?.start() } catch (e: Exception) {}
    }
  }

  @ReactProp(name = "muted")
  fun setMuted(view: RNVideoView, muted: Boolean) {
    view.isMuted = muted
    view.updateVolume()
  }

  @ReactProp(name = "resizeMode")
  fun setResizeMode(view: RNVideoView, resizeMode: String?) {
      view.resizeMode = resizeMode ?: "cover"
      view.requestLayout()
  }

  @ReactProp(name = "trimStartMs")
  fun setTrimStartMs(view: RNVideoView, trimStartMs: Int) {
    view.trimStartMs = trimStartMs
    view.mediaPlayer?.let {
      if (it.currentPosition < trimStartMs) {
        it.seekTo(trimStartMs)
      }
    }
  }

  @ReactProp(name = "trimEndMs")
  fun setTrimEndMs(view: RNVideoView, trimEndMs: Int) {
    view.trimEndMs = trimEndMs
  }

  @ReactProp(name = "seekToMs")
  fun setSeekToMs(view: RNVideoView, seekToMs: Int) {
    if (seekToMs >= 0) {
      if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
        view.mediaPlayer?.seekTo(seekToMs.toLong(), android.media.MediaPlayer.SEEK_CLOSEST)
      } else {
        view.mediaPlayer?.seekTo(seekToMs)
      }
    }
  }
}
