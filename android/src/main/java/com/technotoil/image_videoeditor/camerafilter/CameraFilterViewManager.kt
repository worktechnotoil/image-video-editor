package com.technotoil.image_videoeditor.camerafilter

import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.bridge.ReadableArray

class CameraFilterViewManager : SimpleViewManager<CameraFilterView>() {
  override fun getName(): String = "CameraFilterView"

  override fun createViewInstance(context: ThemedReactContext): CameraFilterView {
    return CameraFilterView(context)
  }

  @ReactProp(name = "filter")
  fun setFilter(view: CameraFilterView, filter: String?) {
    view.setFilter(filter ?: "none")
  }

  @ReactProp(name = "facing")
  fun setFacing(view: CameraFilterView, facing: String?) {
    view.setFacing(facing)
  }

  override fun getCommandsMap(): Map<String, Int> {
    return mapOf(
      "startRecording" to 1,
      "stopRecording" to 2
    )
  }

  override fun receiveCommand(root: CameraFilterView, commandId: String, args: ReadableArray?) {
    super.receiveCommand(root, commandId, args)
    when (commandId) {
      "1" -> {
        // We can't pass Promise easily through receiveCommand natively without NativeModule trick.
        // We can just call it directly. The JS side will use refs.
      }
    }
  }
}
