package com.technotoil.image_videoeditor

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream

object MediaFileUtils {
  fun copyToCache(context: Context, uri: Uri, prefix: String): File {
    val resolver: ContentResolver = context.contentResolver
    val extension = getExtension(resolver, uri)
    val dest = File.createTempFile(prefix, extension?.let { ".${it}" } ?: "", context.cacheDir)
    resolver.openInputStream(uri).use { input ->
      FileOutputStream(dest).use { output ->
        if (input != null) {
          input.copyTo(output)
        }
      }
    }
    return dest
  }

  private fun getExtension(resolver: ContentResolver, uri: Uri): String? {
    val type = resolver.getType(uri) ?: return null
    return MimeTypeMap.getSingleton().getExtensionFromMimeType(type)
  }
}
