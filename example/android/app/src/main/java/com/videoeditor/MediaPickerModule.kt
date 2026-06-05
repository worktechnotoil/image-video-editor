package com.videoeditor

import android.app.Activity
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.facebook.react.bridge.ActivityEventListener
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableArray
import com.facebook.react.modules.core.DeviceEventManagerModule

class MediaPickerModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), ActivityEventListener {

  companion object {
    private const val PICK_MEDIA_REQUEST = 5011
  }

  private var pendingPromise: Promise? = null

  init {
    reactContext.addActivityEventListener(this)
  }

  override fun getName(): String = "RNMediaPicker"

  @ReactMethod
  fun pickMedia(promise: Promise) {
    val activity = getCurrentActivity()
    if (activity == null) {
      promise.reject("no_activity", "Current activity is null")
      return
    }
    if (pendingPromise != null) {
      promise.reject("in_progress", "Another picker request is in progress")
      return
    }
    pendingPromise = promise

    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
    intent.addCategory(Intent.CATEGORY_OPENABLE)
    intent.type = "*/*"
    intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
    intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)

    activity.startActivityForResult(intent, PICK_MEDIA_REQUEST)
  }

  override fun onActivityResult(activity: Activity, requestCode: Int, resultCode: Int, data: Intent?) {
    if (requestCode != PICK_MEDIA_REQUEST) return

    val promise = pendingPromise
    pendingPromise = null

    if (promise == null) return
    if (resultCode != Activity.RESULT_OK || data == null) {
      promise.resolve(Arguments.createArray())
      return
    }

    val results: WritableArray = Arguments.createArray()
    val resolver = reactApplicationContext.contentResolver

    val uris: MutableList<Uri> = mutableListOf()
    val clipData = data.clipData
    if (clipData != null) {
      for (i in 0 until clipData.itemCount) {
        uris.add(clipData.getItemAt(i).uri)
      }
    } else {
      data.data?.let { uris.add(it) }
    }

    for (uri in uris) {
      val mime = resolver.getType(uri) ?: ""
      val type = if (mime.startsWith("video")) "video" else "image"
      val file = MediaFileUtils.copyToCache(reactApplicationContext, uri, "pick")

      val map = Arguments.createMap()
      map.putString("id", java.util.UUID.randomUUID().toString())
      map.putString("uri", Uri.fromFile(file).toString())
      map.putString("type", type)

      if (type == "video") {
        val retriever = MediaMetadataRetriever()
        try {
          retriever.setDataSource(reactApplicationContext, Uri.fromFile(file))
          val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
          durationStr?.toLongOrNull()?.let { map.putDouble("durationMs", it.toDouble()) }
        } catch (_: Exception) {
          // ignore metadata errors
        } finally {
          retriever.release()
        }
      }

      results.pushMap(map)
    }

    promise.resolve(results)
  }

  override fun onNewIntent(intent: Intent) {
    // no-op
  }
}
