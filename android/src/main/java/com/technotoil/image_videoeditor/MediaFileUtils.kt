package com.technotoil.image_videoeditor

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream

object MediaFileUtils {
  fun copyToCache(context: Context, uri: Uri, prefix: String): File {
    val scheme = uri.scheme
    val uriString = uri.toString()

    if (uriString.contains("android_asset")) {
      val assetPath = uriString.substringAfter("android_asset/")
      val dest = File.createTempFile(prefix, ".png", context.cacheDir)
      context.assets.open(assetPath).use { input ->
        FileOutputStream(dest).use { output ->
          input.copyTo(output)
        }
      }
      return dest
    }

    if (scheme == null || scheme == "res" || scheme == "drawable") {
      val resName = uriString.replace("drawable://", "").replace("res://", "").substringAfterLast("/").substringBeforeLast(".")
      val safeName = resName.replace("-", "_").lowercase()
      val resId = context.resources.getIdentifier(safeName, "drawable", context.packageName)
        ?: context.resources.getIdentifier(safeName, "raw", context.packageName)
        ?: context.resources.getIdentifier(safeName, "mipmap", context.packageName)
        ?: context.resources.getIdentifier(resName, "drawable", context.packageName)
      if (resId != 0) {
        val dest = File.createTempFile(prefix, ".png", context.cacheDir)
        context.resources.openRawResource(resId).use { input ->
          FileOutputStream(dest).use { output ->
            input.copyTo(output)
          }
        }
        return dest
      }
    }

    val resolver: ContentResolver = context.contentResolver
    val extension = getExtension(resolver, uri)
    val dest = File.createTempFile(prefix, extension?.let { ".${it}" } ?: "", context.cacheDir)
    try {
      resolver.openInputStream(uri)?.use { input ->
        FileOutputStream(dest).use { output ->
          input.copyTo(output)
        }
      }
    } catch (e: Exception) {
      // Final fallback if scheme is present but it's actually a resource (sometimes happens with custom schemes on Vivo/Oppo)
      val resName = uri.lastPathSegment?.substringBeforeLast(".") ?: uri.toString()
      val safeName = resName.replace("-", "_").lowercase()
      val resId = context.resources.getIdentifier(safeName, "drawable", context.packageName)
        ?: context.resources.getIdentifier(safeName, "raw", context.packageName)
        ?: context.resources.getIdentifier(safeName, "mipmap", context.packageName)
        ?: context.resources.getIdentifier(resName, "drawable", context.packageName)
      if (resId != 0) {
        context.resources.openRawResource(resId).use { input ->
          FileOutputStream(dest).use { output ->
            input.copyTo(output)
          }
        }
      } else {
        throw e
      }
    }
    return dest
  }

  private fun getExtension(resolver: ContentResolver, uri: Uri): String? {
    val type = resolver.getType(uri) ?: return null
    return MimeTypeMap.getSingleton().getExtensionFromMimeType(type)
  }
}
