package com.technotoil.image_videoeditor.camerafilter

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.uimanager.UIManagerModule

class CameraFilterModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  override fun getName(): String = "CameraFilterModule"

  private fun resolveCameraView(nativeViewHierarchyManager: com.facebook.react.uimanager.NativeViewHierarchyManager?, viewTag: Int): CameraFilterView? {
    if (nativeViewHierarchyManager != null) {
      try {
        val view = nativeViewHierarchyManager.resolveView(viewTag) as? CameraFilterView
        if (view != null) return view
      } catch (e: Exception) {}
    }
    return CameraFilterView.activeInstance
  }

  @ReactMethod
  fun startRecording(viewTag: Int, promise: Promise) {
    val context = reactApplicationContext
    val uiManager = context.getNativeModule(UIManagerModule::class.java)
    if (uiManager != null) {
      uiManager.addUIBlock { nativeViewHierarchyManager ->
        try {
          val view = resolveCameraView(nativeViewHierarchyManager, viewTag)
          if (view == null) {
            promise.reject("error", "Camera view not active")
            return@addUIBlock
          }
          view.startRecording(promise)
        } catch (e: Exception) {
          promise.reject("error", e.message)
        }
      }
    } else {
      UiThreadUtil.runOnUiThread {
        val view = CameraFilterView.activeInstance
        if (view == null) {
          promise.reject("error", "Camera view not active")
        } else {
          view.startRecording(promise)
        }
      }
    }
  }

  @ReactMethod
  fun stopRecording(viewTag: Int, promise: Promise) {
    val context = reactApplicationContext
    val uiManager = context.getNativeModule(UIManagerModule::class.java)
    if (uiManager != null) {
      uiManager.addUIBlock { nativeViewHierarchyManager ->
        try {
          val view = resolveCameraView(nativeViewHierarchyManager, viewTag)
          if (view == null) {
            promise.reject("error", "Camera view not active")
            return@addUIBlock
          }
          view.stopRecording(promise)
        } catch (e: Exception) {
          promise.reject("error", e.message)
        }
      }
    } else {
      UiThreadUtil.runOnUiThread {
        val view = CameraFilterView.activeInstance
        if (view == null) {
          promise.reject("error", "Camera view not active")
        } else {
          view.stopRecording(promise)
        }
      }
    }
  }

  @ReactMethod
  fun capturePhoto(viewTag: Int, promise: Promise) {
    val context = reactApplicationContext
    val uiManager = context.getNativeModule(UIManagerModule::class.java)
    if (uiManager != null) {
      uiManager.addUIBlock { nativeViewHierarchyManager ->
        try {
          val view = resolveCameraView(nativeViewHierarchyManager, viewTag)
          if (view == null) {
            promise.reject("error", "Camera view not active")
            return@addUIBlock
          }
          view.capturePhoto(promise)
        } catch (e: Exception) {
          promise.reject("error", e.message)
        }
      }
    } else {
      UiThreadUtil.runOnUiThread {
        val view = CameraFilterView.activeInstance
        if (view == null) {
          promise.reject("error", "Camera view not active")
        } else {
          view.capturePhoto(promise)
        }
      }
    }
  }
}
