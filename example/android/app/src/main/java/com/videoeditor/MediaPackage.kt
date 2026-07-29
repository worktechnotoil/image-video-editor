package com.videoeditor

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.technotoil.image_videoeditor.camerafilter.CameraFilterModule
import com.technotoil.image_videoeditor.camerafilter.CameraFilterViewManager

class MediaPackage : ReactPackage {
  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
    return listOf(
      MediaPickerModule(reactContext),
      MediaEditorModule(reactContext),
      MediaLibraryModule(reactContext),
      MediaPlayerModule(reactContext),
      FrameGrabberModule(reactContext),
      RNCameraModule(reactContext),
      CameraFilterModule(reactContext)
    )
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return listOf(
      RNVideoPreviewManager(reactContext),
      RNCameraViewManager(reactContext),
      CameraFilterViewManager()
    )
  }
}
