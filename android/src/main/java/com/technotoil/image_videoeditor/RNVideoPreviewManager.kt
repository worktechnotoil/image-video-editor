package com.technotoil.image_videoeditor

import android.net.Uri
import android.widget.FrameLayout
import android.widget.VideoView
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.RCTEventEmitter

class RNVideoViewSubclass(context: android.content.Context) : VideoView(context) {
    var resizeMode: String = "cover"
    var videoW: Int = 0
    var videoH: Int = 0

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = MeasureSpec.getSize(heightMeasureSpec)
        setMeasuredDimension(width, height)
    }
}

class VideoProgressEvent(surfaceId: Int, viewTag: Int, private val name: String, private val eventData: com.facebook.react.bridge.WritableMap) :
    com.facebook.react.uimanager.events.Event<VideoProgressEvent>(surfaceId, viewTag) {
    override fun getEventName(): String = name
    override fun getEventData(): com.facebook.react.bridge.WritableMap? = eventData
}

class RNVideoView(context: android.content.Context) : FrameLayout(context) {
    val videoView = RNVideoViewSubclass(context)
    var uri: String? = null
    var isPaused: Boolean = false
    var isMuted: Boolean = true
    var mediaPlayer: android.media.MediaPlayer? = null
    var trimStartMs: Int = 0
    var trimEndMs: Int = 0
    var lastEmittedTime: Int = -1
    var isSeeking: Boolean = false

    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private val checkProgressRunnable = object : Runnable {
        override fun run() {
            try {
                android.util.Log.d("RNVideoPreview", "runnable tick: isPlaying = ${videoView.isPlaying}")
                if (videoView.isPlaying) {
                    val current = videoView.currentPosition
                    if (trimEndMs > 0 && current >= trimEndMs) {
                        if (!isSeeking) {
                            isSeeking = true
                            videoView.seekTo(trimStartMs)
                        }
                    } else if (current < trimStartMs) {
                        if (!isSeeking) {
                            isSeeking = true
                            videoView.seekTo(trimStartMs)
                        }
                    } else {
                        isSeeking = false
                    }

                    if (id != android.view.View.NO_ID && current != lastEmittedTime) {
                        lastEmittedTime = current
                        android.util.Log.d("RNVideoPreview", "Emitting progress: $current, tag: $id")
                        val event = com.facebook.react.bridge.Arguments.createMap().apply {
                            putInt("currentTimeMs", current)
                        }
                        val reactContext = context as? com.facebook.react.bridge.ReactContext
                        if (reactContext != null) {
                            try {
                                val surfaceId = com.facebook.react.uimanager.UIManagerHelper.getSurfaceId(reactContext)
                                val eventDispatcher = com.facebook.react.uimanager.UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)
                                if (eventDispatcher != null) {
                                    eventDispatcher.dispatchEvent(VideoProgressEvent(surfaceId, id, "topChange", event))
                                } else {
                                    reactContext.getJSModule(com.facebook.react.uimanager.events.RCTEventEmitter::class.java)
                                        ?.receiveEvent(id, "topChange", event)
                                }
                            } catch (e: Exception) {
                                try {
                                    reactContext.getJSModule(com.facebook.react.uimanager.events.RCTEventEmitter::class.java)
                                        ?.receiveEvent(id, "topChange", event)
                                } catch (e2: Exception) {
                                    // ignore
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // ignore
            }
            mainHandler.postDelayed(this, 100)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        android.util.Log.d("RNVideoPreview", "onAttachedToWindow called! tag: $id")
        mainHandler.post(checkProgressRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        android.util.Log.d("RNVideoPreview", "onDetachedFromWindow called! tag: $id")
        mainHandler.removeCallbacks(checkProgressRunnable)
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
        
        val videoW = videoView.videoW
        val videoH = videoView.videoH
        
        if (videoW > 0 && videoH > 0 && parentWidth > 0 && parentHeight > 0) {
            val videoAspect = videoW.toFloat() / videoH.toFloat()
            val parentAspect = parentWidth.toFloat() / parentHeight.toFloat()
            
            var childWidth = parentWidth
            var childHeight = parentHeight
            
            if (videoView.resizeMode == "contain") {
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
            
            videoView.measure(
                MeasureSpec.makeMeasureSpec(childWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(childHeight, MeasureSpec.EXACTLY)
            )
        } else {
            videoView.measure(widthMeasureSpec, heightMeasureSpec)
        }
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val parentWidth = right - left
        val parentHeight = bottom - top
        
        val childWidth = videoView.measuredWidth
        val childHeight = videoView.measuredHeight
        
        val childLeft = (parentWidth - childWidth) / 2
        val childTop = (parentHeight - childHeight) / 2
        
        videoView.layout(childLeft, childTop, childLeft + childWidth, childTop + childHeight)
    }

    init {
        android.util.Log.d("RNVideoPreview", "RNVideoView init called! tag: $id")
        clipChildren = true
        videoView.setZOrderMediaOverlay(false)
        videoView.setOnPreparedListener { mp ->
            mediaPlayer = mp
            mp.isLooping = true
            val volume = if (isMuted) 0f else 1f
            mp.setVolume(volume, volume)
            // Seek to trim start before playing
            if (trimStartMs > 0) {
                mp.seekTo(trimStartMs)
            }
            if (!isPaused) {
                android.util.Log.d("RNVideoPreview", "onPrepared: starting playback, isPaused=$isPaused")
                videoView.start()
            } else {
                android.util.Log.d("RNVideoPreview", "onPrepared: isPaused=true, not starting")
            }
            videoView.videoW = mp.videoWidth
            videoView.videoH = mp.videoHeight
            requestLayout()
        }
        videoView.setOnCompletionListener { mp ->
            mp.seekTo(trimStartMs)
            mp.start()
        }
        videoView.setOnErrorListener { mp, what, extra ->
            android.util.Log.e("RNVideoPreview", "VideoView error: what=$what, extra=$extra")
            true // Return true to prevent default "Can't play this video" dialog
        }
        
        val lp = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, android.view.Gravity.CENTER)
        addView(videoView, lp)
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
      view.mediaPlayer = null
      view.videoView.stopPlayback()
      return
    }
    try {
      view.mediaPlayer = null
      val parsedUri = Uri.parse(uri)
      if (parsedUri.scheme == "file" || uri.startsWith("/")) {
        val path = parsedUri.path ?: if (uri.startsWith("file://")) uri.substring(7) else uri
        view.videoView.setVideoPath(path)
      } else {
        view.videoView.setVideoURI(parsedUri)
      }
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  @ReactProp(name = "paused")
  fun setPaused(view: RNVideoView, paused: Boolean) {
    android.util.Log.d("RNVideoPreview", "setPaused: paused=$paused, mediaPlayer=${view.mediaPlayer}")
    view.isPaused = paused
    if (paused) {
      try { view.videoView.pause() } catch (e: Exception) { /* ignore if not yet prepared */ }
    } else {
      // Only call start() if mediaPlayer is prepared (not null)
      if (view.mediaPlayer != null) {
        try {
          if (!view.videoView.isPlaying) {
            view.videoView.start()
          }
        } catch (e: Exception) {
          android.util.Log.w("RNVideoPreview", "setPaused: start() failed: ${e.message}")
        }
      } else {
        android.util.Log.d("RNVideoPreview", "setPaused: mediaPlayer null, will auto-start when prepared")
        // isPaused is already false so onPrepared will call start()
      }
    }
  }

  @ReactProp(name = "muted")
  fun setMuted(view: RNVideoView, muted: Boolean) {
    view.isMuted = muted
    view.updateVolume()
  }

  @ReactProp(name = "resizeMode")
  fun setResizeMode(view: RNVideoView, resizeMode: String?) {
      view.videoView.resizeMode = resizeMode ?: "cover"
      view.videoView.requestLayout()
  }

  @ReactProp(name = "trimStartMs")
  fun setTrimStartMs(view: RNVideoView, trimStartMs: Int) {
    view.trimStartMs = trimStartMs
    if (view.videoView.currentPosition < trimStartMs) {
      view.videoView.seekTo(trimStartMs)
    }
  }

  @ReactProp(name = "trimEndMs")
  fun setTrimEndMs(view: RNVideoView, trimEndMs: Int) {
    view.trimEndMs = trimEndMs
  }

  @ReactProp(name = "seekToMs")
  fun setSeekToMs(view: RNVideoView, seekToMs: Int) {
    if (seekToMs >= 0) {
      view.videoView.seekTo(seekToMs)
    }
  }
}
