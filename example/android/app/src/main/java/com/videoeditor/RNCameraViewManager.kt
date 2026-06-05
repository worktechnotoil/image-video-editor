package com.videoeditor

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.ImageReader
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.net.Uri
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import android.view.TextureView
import android.widget.FrameLayout
import com.facebook.react.bridge.*
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.UIManagerModule
import com.facebook.react.uimanager.annotations.ReactProp
import java.io.File
import java.io.FileOutputStream

@SuppressLint("MissingPermission")
class RNCameraView(context: Context) : FrameLayout(context) {
    private val textureView = TextureView(context)
    var facing: String = "front"
        set(value) {
            if (field != value) {
                field = value
                if (isCameraOpen) {
                    reopenCamera()
                }
            }
        }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var mediaRecorder: MediaRecorder? = null
    private var isCameraOpen = false

    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    private var photoPromise: Promise? = null
    private var videoRecordPromise: Promise? = null
    private var videoStopPromise: Promise? = null
    private var currentVideoFile: File? = null
    private var isRecording = false
    private var flashMode = "off"
    private var previewBuilder: CaptureRequest.Builder? = null

    private var currentPreviewSize: android.util.Size = android.util.Size(1920, 1080)

    private val textureListener = object : TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
            openCamera()
        }
        override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {}
        override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
            closeCamera()
            return true
        }
        override fun onSurfaceTextureUpdated(texture: SurfaceTexture) {}
    }

    private val stateCallback = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            cameraDevice = camera
            isCameraOpen = true
            createCameraPreview()
        }

        override fun onDisconnected(camera: CameraDevice) {
            camera.close()
            cameraDevice = null
            isCameraOpen = false
        }

        override fun onError(camera: CameraDevice, error: Int) {
            camera.close()
            cameraDevice = null
            isCameraOpen = false
            Log.e("RNCameraView", "CameraDevice Error: $error")
        }
    }

    private val imageAvailableListener = ImageReader.OnImageAvailableListener { reader ->
        Log.w("RNCameraView", "imageAvailableListener triggered")
        var image: android.media.Image? = null
        try {
            image = reader.acquireNextImage()
            if (image == null) {
                Log.e("RNCameraView", "No image acquired from reader")
                return@OnImageAvailableListener
            }
            val buffer = image.planes[0].buffer
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)
            
            // Save to cache dir
            val file = File(context.cacheDir, "photo_${System.currentTimeMillis()}.jpg")
            Log.w("RNCameraView", "Saving captured photo to path: ${file.absolutePath}")
            FileOutputStream(file).use { it.write(bytes) }
            
            val options = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
            android.graphics.BitmapFactory.decodeFile(file.absolutePath, options)
            
            Log.w("RNCameraView", "Decoded bounds: width=${options.outWidth}, height=${options.outHeight}")
            val map = Arguments.createMap().apply {
                putString("uri", Uri.fromFile(file).toString())
                putInt("width", options.outWidth)
                putInt("height", options.outHeight)
            }
            
            Log.w("RNCameraView", "Resolving photoPromise with URI: ${Uri.fromFile(file)}")
            photoPromise?.resolve(map)
            photoPromise = null
        } catch (e: Exception) {
            Log.e("RNCameraView", "Error in imageAvailableListener: ${e.message}")
            photoPromise?.reject("save_error", e.message)
            photoPromise = null
        } finally {
            image?.close()
        }
    }

    private fun getOptimalPreviewSize(sizes: Array<android.util.Size>?): android.util.Size {
        if (sizes.isNullOrEmpty()) return android.util.Size(1920, 1080)
        
        val targetRatio = 16.0 / 9.0
        val tolerance = 0.1
        
        val matches = sizes.filter {
            val ratio = it.width.toFloat() / it.height.toFloat()
            Math.abs(ratio - targetRatio) < tolerance || Math.abs((1.0 / ratio) - targetRatio) < tolerance
        }
        
        if (matches.isNotEmpty()) {
            return matches.minByOrNull {
                Math.abs(it.width - 1920) + Math.abs(it.height - 1080)
            } ?: matches[0]
        }
        
        return sizes.minByOrNull {
            Math.abs(it.width - 1920) + Math.abs(it.height - 1080)
        } ?: sizes[0]
    }

    private fun adjustAspectRatio(viewWidth: Int, viewHeight: Int) {
        if (viewWidth == 0 || viewHeight == 0) return
        val previewSize = currentPreviewSize
        
        val previewAspect = previewSize.height.toFloat() / previewSize.width.toFloat()
        val viewAspect = viewWidth.toFloat() / viewHeight.toFloat()
        
        val matrix = android.graphics.Matrix()
        
        var scaleX = 1f
        var scaleY = 1f
        
        if (viewAspect > previewAspect) {
            scaleY = viewAspect / previewAspect
        } else {
            scaleX = previewAspect / viewAspect
        }
        
        matrix.setScale(scaleX, scaleY, viewWidth / 2f, viewHeight / 2f)
        
        val reactContext = context as? com.facebook.react.bridge.ReactContext
        if (reactContext != null) {
            reactContext.runOnUiQueueThread {
                textureView.setTransform(matrix)
            }
        } else {
            textureView.setTransform(matrix)
        }
    }

    init {
        addView(textureView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        textureView.surfaceTextureListener = textureListener
        textureView.addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
            adjustAspectRatio(right - left, bottom - top)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startBackgroundThread()
        if (textureView.isAvailable) {
            openCamera()
        }
    }

    override fun onDetachedFromWindow() {
        closeCamera()
        stopBackgroundThread()
        super.onDetachedFromWindow()
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            e.printStackTrace()
        }
    }

    private fun openCamera() {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            val cameraId = manager.cameraIdList.firstOrNull { id ->
                val chars = manager.getCameraCharacteristics(id)
                val facingChar = chars.get(CameraCharacteristics.LENS_FACING)
                if (facing == "back") facingChar == CameraMetadata.LENS_FACING_BACK
                else facingChar == CameraMetadata.LENS_FACING_FRONT
            } ?: manager.cameraIdList.firstOrNull() ?: return

            manager.openCamera(cameraId, stateCallback, backgroundHandler)
        } catch (e: Exception) {
            Log.e("RNCameraView", "openCamera failed: ${e.message}")
        }
    }

    private fun closeCamera() {
        try {
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null
            isCameraOpen = false
            imageReader?.close()
            imageReader = null

            mediaRecorder?.let {
                try {
                    it.reset()
                } catch (e: Exception) {}
                try {
                    it.release()
                } catch (e: Exception) {}
            }
            mediaRecorder = null
            isRecording = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun reopenCamera() {
        closeCamera()
        openCamera()
    }

    private fun createCameraPreview() {
        val device = cameraDevice ?: return
        val texture = textureView.surfaceTexture ?: return
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            val chars = manager.getCameraCharacteristics(device.id)
            val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val previewSize = getOptimalPreviewSize(map?.getOutputSizes(SurfaceTexture::class.java))
            currentPreviewSize = previewSize
            texture.setDefaultBufferSize(previewSize.width, previewSize.height)
            val reactContext = context as? com.facebook.react.bridge.ReactContext
            reactContext?.runOnUiQueueThread {
                adjustAspectRatio(textureView.width, textureView.height)
            }
            
            val surface = Surface(texture)

            // Image reader setup
            val readerSizes = map?.getOutputSizes(ImageFormat.JPEG) ?: emptyArray()
            val photoSize = readerSizes.firstOrNull() ?: android.util.Size(1920, 1080)
            imageReader = ImageReader.newInstance(photoSize.width, photoSize.height, ImageFormat.JPEG, 2)
            imageReader?.setOnImageAvailableListener(imageAvailableListener, backgroundHandler)

            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            builder.addTarget(surface)
            val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
            if (hasFlash) {
                if (flashMode == "on") {
                    builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_TORCH)
                } else {
                    builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
                }
            }
            previewBuilder = builder

            device.createCaptureSession(listOf(surface, imageReader!!.surface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (cameraDevice == null) return
                    captureSession = session
                    builder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                    try {
                        session.setRepeatingRequest(builder.build(), null, backgroundHandler)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e("RNCameraView", "Preview session configuration failed")
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun capturePhoto(promise: Promise) {
        Log.w("RNCameraView", "capturePhoto called")
        val device = cameraDevice ?: run {
            Log.e("RNCameraView", "capturePhoto error: Camera not ready")
            return promise.reject("camera_error", "Camera not ready")
        }
        val reader = imageReader ?: run {
            Log.e("RNCameraView", "capturePhoto error: ImageReader not ready")
            return promise.reject("camera_error", "ImageReader not ready")
        }
        val session = captureSession ?: run {
            Log.e("RNCameraView", "capturePhoto error: Session not ready")
            return promise.reject("camera_error", "Session not ready")
        }

        photoPromise = promise

        try {
            val captureBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(reader.surface)
            captureBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)

            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = manager.getCameraCharacteristics(device.id)
            val sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            captureBuilder.set(CaptureRequest.JPEG_ORIENTATION, sensorOrientation)

            val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
            if (hasFlash) {
                if (flashMode == "on") {
                    captureBuilder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_TORCH)
                } else {
                    captureBuilder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
                }
            }

            // session.stopRepeating()
            Log.w("RNCameraView", "Calling session.capture")
            session.capture(captureBuilder.build(), object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureStarted(session: CameraCaptureSession, request: CaptureRequest, timestamp: Long, frameNumber: Long) {
                    Log.w("RNCameraView", "onCaptureStarted: timestamp=$timestamp, frameNumber=$frameNumber")
                }

                override fun onCaptureFailed(session: CameraCaptureSession, request: CaptureRequest, failure: CaptureFailure) {
                    Log.e("RNCameraView", "onCaptureFailed: reason=${failure.reason}, wasImageCaptured=${failure.wasImageCaptured()}")
                    photoPromise?.reject("capture_failed", "Capture failed: reason=${failure.reason}")
                    photoPromise = null
                }

                override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                    Log.w("RNCameraView", "onCaptureCompleted triggered")
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            Log.e("RNCameraView", "capturePhoto exception: ${e.message}")
            promise.reject("capture_error", e.message)
            photoPromise = null
        }
    }

    fun startRecording(promise: Promise) {
        if (isRecording) {
            return promise.reject("already_recording", "Camera is already recording video.")
        }
        val recordAudioPermission = androidx.core.content.ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.RECORD_AUDIO
        )
        if (recordAudioPermission != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return promise.reject("permission_denied", "Microphone permission is not granted.")
        }
        val cameraPermission = androidx.core.content.ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.CAMERA
        )
        if (cameraPermission != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return promise.reject("permission_denied", "Camera permission is not granted.")
        }
        val device = cameraDevice ?: return promise.reject("camera_error", "Camera not ready")
        val texture = textureView.surfaceTexture ?: return promise.reject("camera_error", "Texture not ready")

        videoRecordPromise = promise
        currentVideoFile = File(context.cacheDir, "video_${System.currentTimeMillis()}.mp4")

        try {
            closeCamera() // Close standard preview first
            openCamera() // Wait for camera to open and prepare recorder
            
            // Wait for cameraDevice is ready to record
            backgroundHandler?.post {
                while (cameraDevice == null) {
                    Thread.sleep(50)
                }
                
                val recordDevice = cameraDevice!!
                val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val chars = manager.getCameraCharacteristics(recordDevice.id)
                val sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90

                mediaRecorder = MediaRecorder(context).apply {
                    setAudioSource(MediaRecorder.AudioSource.MIC)
                    setVideoSource(MediaRecorder.VideoSource.SURFACE)
                    setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                    setOutputFile(currentVideoFile!!.absolutePath)
                    setVideoEncodingBitRate(10000000)
                    setVideoFrameRate(30)
                    setVideoSize(1280, 720)
                    setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    
                    // Front camera video needs correct rotation
                    setOrientationHint(sensorOrientation)
                    prepare()
                }

                val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                val previewSize = getOptimalPreviewSize(map?.getOutputSizes(SurfaceTexture::class.java))
                currentPreviewSize = previewSize
                texture.setDefaultBufferSize(previewSize.width, previewSize.height)
                val reactContext = context as? com.facebook.react.bridge.ReactContext
                reactContext?.runOnUiQueueThread {
                    adjustAspectRatio(textureView.width, textureView.height)
                }

                val previewSurface = Surface(texture)
                val recorderSurface = mediaRecorder!!.surface

                val recordBuilder = recordDevice.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                recordBuilder.addTarget(previewSurface)
                recordBuilder.addTarget(recorderSurface)

                val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
                if (hasFlash) {
                    if (flashMode == "on") {
                        recordBuilder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_TORCH)
                    } else {
                        recordBuilder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
                    }
                }

                recordDevice.createCaptureSession(listOf(previewSurface, recorderSurface), object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        recordBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                        try {
                            session.setRepeatingRequest(recordBuilder.build(), null, backgroundHandler)
                            mediaRecorder!!.start()
                            isRecording = true
                            videoRecordPromise?.resolve(null)
                            videoRecordPromise = null
                        } catch (e: Exception) {
                            videoRecordPromise?.reject("record_error", e.message)
                            videoRecordPromise = null
                        }
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        videoRecordPromise?.reject("record_error", "Video Session configure failed")
                        videoRecordPromise = null
                    }
                }, backgroundHandler)
            }
        } catch (e: Exception) {
            promise.reject("record_error", e.message)
            videoRecordPromise = null
        }
    }

    fun stopRecording(promise: Promise) {
        if (!isRecording || mediaRecorder == null) {
            return promise.reject("not_recording", "Camera is not recording.")
        }

        videoStopPromise = promise

        backgroundHandler?.post {
            try {
                mediaRecorder!!.stop()
                mediaRecorder!!.reset()
                mediaRecorder = null
                isRecording = false

                val file = currentVideoFile ?: return@post promise.reject("error", "Recorded video file is missing")
                
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(file.absolutePath)
                val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1280
                val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 720
                retriever.release()

                val map = Arguments.createMap().apply {
                    putString("uri", Uri.fromFile(file).toString())
                    putDouble("durationMs", duration.toDouble())
                    putInt("width", width)
                    putInt("height", height)
                }

                // Reopen normal camera preview
                reopenCamera()

                videoStopPromise?.resolve(map)
                videoStopPromise = null
            } catch (e: Exception) {
                videoStopPromise?.reject("stop_error", e.message)
                videoStopPromise = null
                reopenCamera()
            }
        }
    }

    class CameraEvent(surfaceId: Int, viewId: Int, private val name: String, private val data: WritableMap?) :
        com.facebook.react.uimanager.events.Event<CameraEvent>(surfaceId, viewId) {
        
        override fun getEventName(): String = name
        override fun getEventData(): WritableMap? = data
    }

    private fun emitEvent(eventName: String, eventData: WritableMap?) {
        Log.w("RNCameraView", "emitEvent called: eventName=$eventName, eventData=$eventData")
        val reactContext = context as? ReactContext ?: return
        try {
            val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
            val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)
            if (dispatcher != null) {
                Log.w("RNCameraView", "emitEvent: using dispatcher")
                dispatcher.dispatchEvent(CameraEvent(surfaceId, id, eventName, eventData))
            } else {
                Log.w("RNCameraView", "emitEvent: dispatcher is null, using RCTEventEmitter")
                reactContext.getJSModule(com.facebook.react.uimanager.events.RCTEventEmitter::class.java)
                    ?.receiveEvent(id, eventName, eventData)
            }
        } catch (e: Exception) {
            Log.w("RNCameraView", "emitEvent: first attempt failed, trying fallback: ${e.message}")
            try {
                reactContext.getJSModule(com.facebook.react.uimanager.events.RCTEventEmitter::class.java)
                    ?.receiveEvent(id, eventName, eventData)
            } catch (e2: Exception) {
                Log.e("RNCameraView", "emitEvent error: ${e2.message}")
                e2.printStackTrace()
            }
        }
    }

    class EventPromise(
        private val eventName: String,
        private val emit: (String, WritableMap?) -> Unit
    ) : Promise {
        override fun resolve(value: Any?) {
            val map = value as? WritableMap
            emit(eventName, map)
        }

        override fun reject(code: String?, message: String?) {
            val map = Arguments.createMap().apply {
                putString("error", message ?: "Unknown error")
            }
            emit(eventName, map)
        }

        override fun reject(code: String?, throwable: Throwable?) {
            reject(code, throwable?.message)
        }

        override fun reject(code: String?, message: String?, throwable: Throwable?) {
            reject(code, message)
        }

        override fun reject(throwable: Throwable) {
            reject("error", throwable.message)
        }

        override fun reject(throwable: Throwable, userInfo: WritableMap) {
            reject("error", throwable.message)
        }

        override fun reject(code: String?, userInfo: WritableMap) {
            reject(code, "error")
        }

        override fun reject(code: String?, throwable: Throwable?, userInfo: WritableMap) {
            reject(code, throwable?.message)
        }

        override fun reject(code: String?, message: String?, userInfo: WritableMap) {
            reject(code, message)
        }

        override fun reject(code: String?, message: String?, throwable: Throwable?, userInfo: WritableMap?) {
            reject(code, message)
        }

        override fun reject(message: String) {
            reject("error", message)
        }
    }

    fun setPhotoTrigger(trigger: String?) {
        Log.w("RNCameraView", "setPhotoTrigger called with: $trigger")
        if (trigger.isNullOrEmpty()) return
        val promise = EventPromise("topPhotoCaptured", ::emitEvent)
        capturePhoto(promise)
    }

    fun setRecordTrigger(trigger: String?) {
        if (trigger == "start") {
            val startPromise = EventPromise("topRecordStarted", ::emitEvent)
            startRecording(startPromise)
        } else if (trigger == "stop") {
            val stopPromise = EventPromise("topRecordStopped", ::emitEvent)
            stopRecording(stopPromise)
        }
    }

    fun setFlashMode(flash: String?) {
        val newFlash = flash ?: "off"
        if (flashMode != newFlash) {
            flashMode = newFlash
            applyFlashToPreview()
        }
    }

    private fun applyFlashToPreview() {
        val session = captureSession ?: return
        val builder = previewBuilder ?: return
        val device = cameraDevice ?: return
        try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val chars = manager.getCameraCharacteristics(device.id)
            val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
            if (hasFlash) {
                if (flashMode == "on") {
                    builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_TORCH)
                } else {
                    builder.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
                }
                session.setRepeatingRequest(builder.build(), null, backgroundHandler)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

class RNCameraViewManager(private val reactContext: ReactApplicationContext) :
    SimpleViewManager<RNCameraView>() {

    override fun getName(): String = "RNCameraView"

    override fun createViewInstance(reactContext: ThemedReactContext): RNCameraView {
        return RNCameraView(reactContext)
    }

    @ReactProp(name = "facing")
    fun setFacing(view: RNCameraView, facing: String?) {
        view.facing = facing ?: "front"
    }

    @ReactProp(name = "flashMode")
    fun setFlashMode(view: RNCameraView, flashMode: String?) {
        view.setFlashMode(flashMode)
    }

    @ReactProp(name = "photoTrigger")
    fun setPhotoTrigger(view: RNCameraView, photoTrigger: String?) {
        view.setPhotoTrigger(photoTrigger)
    }

    @ReactProp(name = "recordTrigger")
    fun setRecordTrigger(view: RNCameraView, recordTrigger: String?) {
        view.setRecordTrigger(recordTrigger)
    }

    override fun getExportedCustomDirectEventTypeConstants(): Map<String, Any> {
        return com.facebook.react.common.MapBuilder.builder<String, Any>()
            .put("topPhotoCaptured", com.facebook.react.common.MapBuilder.of("registrationName", "onPhotoCaptured"))
            .put("topRecordStarted", com.facebook.react.common.MapBuilder.of("registrationName", "onRecordStarted"))
            .put("topRecordStopped", com.facebook.react.common.MapBuilder.of("registrationName", "onRecordStopped"))
            .build()
    }
}

class RNCameraModule(private val reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "RNCameraModule"

    @ReactMethod
    fun capturePhoto(reactTag: Int, promise: Promise) {
        val uiManager = reactContext.getNativeModule(UIManagerModule::class.java)
        reactContext.runOnUiQueueThread {
            try {
                val view = uiManager?.resolveView(reactTag) as? RNCameraView
                if (view != null) {
                    view.capturePhoto(promise)
                } else {
                    promise.reject("error", "Camera view not found")
                }
            } catch (e: Exception) {
                promise.reject("error", e.message)
            }
        }
    }

    @ReactMethod
    fun startRecording(reactTag: Int, promise: Promise) {
        val uiManager = reactContext.getNativeModule(UIManagerModule::class.java)
        reactContext.runOnUiQueueThread {
            try {
                val view = uiManager?.resolveView(reactTag) as? RNCameraView
                if (view != null) {
                    view.startRecording(promise)
                } else {
                    promise.reject("error", "Camera view not found")
                }
            } catch (e: Exception) {
                promise.reject("error", e.message)
            }
        }
    }

    @ReactMethod
    fun stopRecording(reactTag: Int, promise: Promise) {
        val uiManager = reactContext.getNativeModule(UIManagerModule::class.java)
        reactContext.runOnUiQueueThread {
            try {
                val view = uiManager?.resolveView(reactTag) as? RNCameraView
                if (view != null) {
                    view.stopRecording(promise)
                } else {
                    promise.reject("error", "Camera view not found")
                }
            } catch (e: Exception) {
                promise.reject("error", e.message)
            }
        }
    }
}
