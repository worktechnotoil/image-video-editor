package com.technotoil.image_videoeditor.camerafilter

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.uimanager.UIManagerModule

class CameraFilterModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  override fun getName(): String = "CameraFilterModule"

  @ReactMethod
  fun startRecording(viewTag: Int, promise: Promise) {
    val context = reactApplicationContext
    val uiManager = context.getNativeModule(UIManagerModule::class.java)
    uiManager?.addUIBlock { nativeViewHierarchyManager ->
      try {
        val view = nativeViewHierarchyManager.resolveView(viewTag) as? CameraFilterView
        if (view == null) {
          promise.reject("error", "View not found")
          return@addUIBlock
        }
        view.startRecording(promise)
      } catch (e: Exception) {
        promise.reject("error", e.message)
      }
    }
  }

  @ReactMethod
  fun stopRecording(viewTag: Int, promise: Promise) {
    val context = reactApplicationContext
    val uiManager = context.getNativeModule(UIManagerModule::class.java)
    uiManager?.addUIBlock { nativeViewHierarchyManager ->
      try {
        val view = nativeViewHierarchyManager.resolveView(viewTag) as? CameraFilterView
        if (view == null) {
          promise.reject("error", "View not found")
          return@addUIBlock
        }
        view.stopRecording(promise)
      } catch (e: Exception) {
        promise.reject("error", e.message)
      }
    }
  }

  @ReactMethod
  fun capturePhoto(viewTag: Int, promise: Promise) {
    val context = reactApplicationContext
    val uiManager = context.getNativeModule(UIManagerModule::class.java)
    uiManager?.addUIBlock { nativeViewHierarchyManager ->
      try {
        val view = nativeViewHierarchyManager.resolveView(viewTag) as? CameraFilterView
        if (view == null) {
          promise.reject("error", "View not found")
          return@addUIBlock
        }
        view.capturePhoto(promise)
      } catch (e: Exception) {
        promise.reject("error", e.message)
      }
    }
  }
}
