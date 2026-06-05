package com.videoeditor

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import java.io.File
import java.io.FileOutputStream

class MediaLibraryModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "RNMediaLibrary"

  @ReactMethod
  fun requestAccess(promise: Promise) {
    val activity = getCurrentActivity()
    if (activity == null) {
      promise.resolve(false)
      return
    }
    val permissions = if (android.os.Build.VERSION.SDK_INT >= 33) {
      arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
    } else {
      arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }
    val allGranted = permissions.all {
      ContextCompat.checkSelfPermission(reactContext, it) == PackageManager.PERMISSION_GRANTED
    }
    if (allGranted) {
      promise.resolve(true)
      return
    }
    if (activity is com.facebook.react.modules.core.PermissionAwareActivity) {
      activity.requestPermissions(permissions, 4422,
        com.facebook.react.modules.core.PermissionListener { _: Int, _: Array<String>, grantResults: IntArray ->
          val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
          promise.resolve(granted)
          granted
        }
      )
    } else {
      ActivityCompat.requestPermissions(activity, permissions, 4422)
      promise.resolve(false)
    }
  }

  @ReactMethod
  fun listAlbums(promise: Promise) {
    try {
      val albums = Arguments.createArray()
      val projection = arrayOf(
        MediaStore.Files.FileColumns.BUCKET_ID,
        MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME
      )
      
      val cursor = reactContext.contentResolver.query(
        MediaStore.Files.getContentUri("external"),
        projection,
        null,
        null,
        "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"
      )

      val seenIds = mutableSetOf<String>()
      if (cursor != null) {
        val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_ID)
        val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)
        
        while (cursor.moveToNext()) {
          val id = cursor.getString(idCol)
          val name = cursor.getString(nameCol) ?: "Unknown"
          if (!seenIds.contains(id)) {
            val map = Arguments.createMap()
            map.putString("id", id)
            map.putString("title", name)
            albums.pushMap(map)
            seenIds.add(id)
          }
        }
        cursor.close()
      }
      promise.resolve(albums)
    } catch (e: Exception) {
      promise.reject("albums_failed", e.message, e)
    }
  }

  @ReactMethod
  fun listMedia(options: com.facebook.react.bridge.ReadableMap, promise: Promise) {
    try {
      val limit = if (options.hasKey("limit")) options.getInt("limit") else 200
      val offset = if (options.hasKey("offset")) options.getInt("offset") else 0
      val type = if (options.hasKey("type")) options.getString("type") else "all"
      val albumId = if (options.hasKey("albumId")) options.getString("albumId") else null

      val resolver = reactContext.contentResolver
      val items = Arguments.createArray()

      val projection = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.Files.FileColumns.DURATION,
      )

      var selection = when (type) {
        "image" -> "${MediaStore.Files.FileColumns.MEDIA_TYPE}=${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}"
        "video" -> "${MediaStore.Files.FileColumns.MEDIA_TYPE}=${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO}"
        else -> "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}, ${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})"
      }

      if (albumId != null) {
        selection += " AND ${MediaStore.Files.FileColumns.BUCKET_ID} = '$albumId'"
      }

      val sortOrder = "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"

      val queryUri = MediaStore.Files.getContentUri("external")
      val cursor = resolver.query(queryUri, projection, selection, null, sortOrder)

      if (cursor != null) {
        val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
        val typeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
        val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DURATION)

        var skipped = 0
        while (cursor.moveToNext() && items.size() < limit) {
          if (skipped < offset) {
            skipped++
            continue
          }
          val id = cursor.getLong(idCol)
          val mediaType = cursor.getInt(typeCol)
          val duration = cursor.getLong(durationCol)

          val uri = if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) {
            ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
          } else {
            ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
          }

          val thumbUri = if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) {
            createVideoThumbnail(uri, id)
          } else {
            uri.toString()
          }

          val map = Arguments.createMap()
          map.putString("id", id.toString())
          map.putString("uri", uri.toString())
          map.putString("thumbnailUri", thumbUri ?: "")
          map.putString("type", if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) "video" else "image")
          if (mediaType == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO) {
            map.putDouble("durationMs", duration.toDouble())
          }

          items.pushMap(map)
        }
        cursor.close()
      }

      promise.resolve(items)
    } catch (e: Exception) {
      promise.reject("list_failed", e.message, e)
    }
  }

  private fun createVideoThumbnail(uri: Uri, id: Long): String? {
    return try {
      val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= 29) {
        reactContext.contentResolver.loadThumbnail(uri, Size(240, 240), null)
      } else {
        MediaStore.Video.Thumbnails.getThumbnail(
          reactContext.contentResolver,
          id,
          MediaStore.Video.Thumbnails.MINI_KIND,
          null
        )
      }
      if (bitmap == null) return null
      val file = File.createTempFile("vthumb_", ".jpg", reactContext.cacheDir)
      FileOutputStream(file).use { out ->
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
      }
      Uri.fromFile(file).toString()
    } catch (_: Exception) {
      null
    }
  }

  @ReactMethod
  fun exportAsset(localId: String, promise: Promise) {
    try {
      val id = localId.toLong()
      val resolver = reactContext.contentResolver
      var uri: Uri? = null

      // Check if it is a video first
      val videoUri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
      var cursor = resolver.query(videoUri, arrayOf(MediaStore.Video.Media._ID), null, null, null)
      if (cursor != null) {
        if (cursor.moveToFirst()) {
          uri = videoUri
        }
        cursor.close()
      }

      // If not a video, check if it's an image
      if (uri == null) {
        val imageUri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        cursor = resolver.query(imageUri, arrayOf(MediaStore.Images.Media._ID), null, null, null)
        if (cursor != null) {
          if (cursor.moveToFirst()) {
            uri = imageUri
          }
          cursor.close()
        }
      }

      if (uri != null) {
        val cacheFile = MediaFileUtils.copyToCache(reactContext, uri, "export")
        promise.resolve(Uri.fromFile(cacheFile).toString())
      } else {
        promise.reject("not_found", "Asset not found in Video or Image MediaStore")
      }
    } catch (e: Exception) {
      promise.reject("export_failed", e.message, e)
    }
  }

  @ReactMethod
  fun saveToGallery(uriString: String, type: String, promise: Promise) {
    try {
      val uri = Uri.parse(uriString)
      val resolver = reactContext.contentResolver
      val currentTime = System.currentTimeMillis()
      val extension = if (type == "video") ".mp4" else ".jpg"
      val mimeType = if (type == "video") "video/mp4" else "image/jpeg"
      val displayName = "Edited_$currentTime$extension"

      val values = android.content.ContentValues().apply {
        put(MediaStore.Files.FileColumns.DISPLAY_NAME, displayName)
        put(MediaStore.Files.FileColumns.DATE_ADDED, currentTime / 1000)
        put(MediaStore.Files.FileColumns.DATE_TAKEN, currentTime)
        put(MediaStore.Files.FileColumns.MIME_TYPE, mimeType)
        if (Build.VERSION.SDK_INT >= 29) {
          put(MediaStore.Files.FileColumns.IS_PENDING, 1)
          val relativePath = if (type == "video") "Movies/VideoEditor" else "Pictures/VideoEditor"
          put(MediaStore.Files.FileColumns.RELATIVE_PATH, relativePath)
        }
      }

      val targetUri = if (type == "video") {
        MediaStore.Video.Media.EXTERNAL_CONTENT_URI
      } else {
        MediaStore.Images.Media.EXTERNAL_CONTENT_URI
      }

      val insertedUri = resolver.insert(targetUri, values)
      if (insertedUri == null) {
        promise.reject("insert_failed", "Could not create gallery entry")
        return
      }

      try {
        resolver.openInputStream(uri).use { input ->
          resolver.openOutputStream(insertedUri).use { output ->
            if (input != null && output != null) {
              input.copyTo(output)
            } else {
              promise.reject("io_failed", "Could not copy file to gallery")
              return
            }
          }
        }

        if (Build.VERSION.SDK_INT >= 29) {
          values.clear()
          values.put(MediaStore.Files.FileColumns.IS_PENDING, 0)
          resolver.update(insertedUri, values, null, null)
        }
        
        promise.resolve(insertedUri.toString())
      } catch (e: Exception) {
        // Clean up the failed insert
        resolver.delete(insertedUri, null, null)
        throw e
      }
    } catch (e: Exception) {
      promise.reject("save_failed", e.message, e)
    }
  }
}
