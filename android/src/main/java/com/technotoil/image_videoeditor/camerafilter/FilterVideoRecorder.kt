package com.technotoil.image_videoeditor.camerafilter

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.view.Surface
import android.graphics.Canvas
import kotlin.concurrent.thread

class FilterVideoRecorder(
    private val outputFile: String,
    private val width: Int = 720,
    private val height: Int = 1280,
    private val drawCallback: (Canvas) -> Unit
) {

    private var videoCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    
    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var muxerStarted = false
    @Volatile private var isRecording = false
    @Volatile private var isStopping = false
    
    private var audioRecord: AudioRecord? = null
    private val bufferInfo = MediaCodec.BufferInfo()
    private val audioBufferInfo = MediaCodec.BufferInfo()

    private var videoDrainThread: Thread? = null
    private var audioDrainThread: Thread? = null

    private var lastFrameTimeNs: Long = 0
    private val minFrameIntervalNs = 32_000_000L // ~32ms target (30 FPS normal speed)

    @Volatile private var firstVideoPtsUs: Long = -1L
    @Volatile private var firstAudioPtsUs: Long = -1L
    @Volatile private var audioPtsUs: Long = 0L

    private val sampleRate = 44100
    private val channelCount = 1 // MONO configuration prevents multi-mic acoustic echo
    private val bytesPerFrame = 2 * channelCount // 16-bit PCM mono = 2 bytes per frame

    fun start() {
        isRecording = true
        isStopping = false
        lastFrameTimeNs = 0
        firstVideoPtsUs = -1L
        firstAudioPtsUs = -1L
        audioPtsUs = 0L
        muxer = MediaMuxer(outputFile, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        setupVideoCodec()
        setupAudioCodec()
        startAudioCapture()
        
        videoDrainThread = thread { drainVideoCodec() }
        audioDrainThread = thread { drainAudioCodec() }
    }

    private fun setupVideoCodec() {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 6000000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        videoCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = videoCodec?.createInputSurface()
        videoCodec?.start()
    }

    private fun setupAudioCodec() {
        try {
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channelCount).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 96000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }
            audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            audioCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            audioCodec?.start()
        } catch (e: Exception) {
            e.printStackTrace()
            audioCodec = null
        }
    }

    private fun startAudioCapture() {
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        try {
            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat).coerceAtLeast(4096)
            if (minBufferSize > 0) {
                val record = AudioRecord(MediaRecorder.AudioSource.CAMCORDER, sampleRate, channelConfig, audioFormat, minBufferSize * 2)
                if (record.state == AudioRecord.STATE_INITIALIZED) {
                    record.startRecording()
                    audioRecord = record
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            audioRecord = null
        }
        
        thread {
            try {
                val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat).coerceAtLeast(4096)
                val buffer = ByteArray(minBufferSize)
                while (isRecording) {
                    val record = audioRecord ?: break
                    val readBytes = record.read(buffer, 0, buffer.size)
                    if (readBytes > 0) {
                        val codec = audioCodec ?: break
                        val inputBufferIndex = codec.dequeueInputBuffer(10000)
                        if (inputBufferIndex >= 0) {
                            val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                            if (inputBuffer != null) {
                                inputBuffer.clear()
                                val bytesToWrite = Math.min(readBytes, inputBuffer.remaining())
                                if (bytesToWrite > 0) {
                                    inputBuffer.put(buffer, 0, bytesToWrite)
                                    codec.queueInputBuffer(inputBufferIndex, 0, bytesToWrite, audioPtsUs, 0)
                                    val framesWritten = bytesToWrite / bytesPerFrame
                                    audioPtsUs += (framesWritten * 1_000_000L) / sampleRate.toLong()
                                }
                            }
                        }
                    } else {
                        try { Thread.sleep(10) } catch (e: Exception) {}
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private val renderExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val isRendering = java.util.concurrent.atomic.AtomicBoolean(false)

    fun onFrame() {
        if (!isRecording) return
        val nowNs = System.nanoTime()
        if (lastFrameTimeNs != 0L && (nowNs - lastFrameTimeNs) < minFrameIntervalNs) {
            return
        }
        if (!isRendering.compareAndSet(false, true)) return
        lastFrameTimeNs = nowNs
        renderExecutor.execute {
            try {
                if (!isRecording) return@execute
                val canvas = inputSurface?.lockCanvas(null) ?: return@execute
                try {
                    drawCallback(canvas)
                } finally {
                    inputSurface?.unlockCanvasAndPost(canvas)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                isRendering.set(false)
            }
        }
    }

    private fun drainVideoCodec() {
        try {
            val startWait = System.currentTimeMillis()
            var eosReached = false
            var consecutiveTimeouts = 0
            while (!eosReached) {
                if (!muxerStarted && videoTrackIndex >= 0 && (audioCodec == null || System.currentTimeMillis() - startWait > 400)) {
                    checkMuxerStart(force = true)
                }
                val index = videoCodec?.dequeueOutputBuffer(bufferInfo, 10000) ?: -1
                if (index == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (isStopping) {
                        consecutiveTimeouts++
                        if (consecutiveTimeouts >= 5) {
                            break
                        }
                    }
                } else if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (!muxerStarted) {
                        videoTrackIndex = muxer?.addTrack(videoCodec!!.outputFormat) ?: -1
                        checkMuxerStart()
                    }
                } else if (index >= 0) {
                    consecutiveTimeouts = 0
                    val encodedData = videoCodec?.getOutputBuffer(index)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) bufferInfo.size = 0
                    if (bufferInfo.size != 0 && muxerStarted) {
                        if (firstVideoPtsUs < 0) {
                            firstVideoPtsUs = bufferInfo.presentationTimeUs
                        }
                        bufferInfo.presentationTimeUs = Math.max(0L, bufferInfo.presentationTimeUs - firstVideoPtsUs)
                        encodedData?.position(bufferInfo.offset)
                        encodedData?.limit(bufferInfo.offset + bufferInfo.size)
                        muxer?.writeSampleData(videoTrackIndex, encodedData!!, bufferInfo)
                    }
                    videoCodec?.releaseOutputBuffer(index, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        eosReached = true
                        break
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun drainAudioCodec() {
        if (audioCodec == null) return
        try {
            var eosReached = false
            var consecutiveTimeouts = 0
            while (!eosReached) {
                val index = audioCodec?.dequeueOutputBuffer(audioBufferInfo, 10000) ?: -1
                if (index == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (isStopping) {
                        consecutiveTimeouts++
                        if (consecutiveTimeouts >= 5) {
                            break
                        }
                    }
                } else if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (!muxerStarted) {
                        audioTrackIndex = muxer?.addTrack(audioCodec!!.outputFormat) ?: -1
                        checkMuxerStart()
                    }
                } else if (index >= 0) {
                    consecutiveTimeouts = 0
                    val encodedData = audioCodec?.getOutputBuffer(index)
                    if (audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) audioBufferInfo.size = 0
                    if (audioBufferInfo.size != 0 && muxerStarted && audioTrackIndex >= 0) {
                        if (firstAudioPtsUs < 0) {
                            firstAudioPtsUs = audioBufferInfo.presentationTimeUs
                        }
                        audioBufferInfo.presentationTimeUs = Math.max(0L, audioBufferInfo.presentationTimeUs - firstAudioPtsUs)
                        encodedData?.position(audioBufferInfo.offset)
                        encodedData?.limit(audioBufferInfo.offset + audioBufferInfo.size)
                        muxer?.writeSampleData(audioTrackIndex, encodedData!!, audioBufferInfo)
                    }
                    audioCodec?.releaseOutputBuffer(index, false)
                    if (audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        eosReached = true
                        break
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Synchronized
    private fun checkMuxerStart(force: Boolean = false) {
        if (!muxerStarted && videoTrackIndex >= 0) {
            if (force || audioCodec == null || audioTrackIndex >= 0) {
                try {
                    muxer?.start()
                    muxerStarted = true
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    fun stop() {
        isRecording = false
        isStopping = true
        renderExecutor.shutdown()
        
        try { audioRecord?.stop() } catch (e: Exception) {}
        try { audioRecord?.release() } catch (e: Exception) {}
        
        try {
            videoCodec?.signalEndOfInputStream()
        } catch(e: Exception){}

        try {
            videoDrainThread?.join(1000)
            audioDrainThread?.join(500)
        } catch (e: Exception) {}

        try { videoCodec?.stop() } catch (e: Exception) {}
        try { videoCodec?.release() } catch (e: Exception) {}
        videoCodec = null

        try { audioCodec?.stop() } catch (e: Exception) {}
        try { audioCodec?.release() } catch (e: Exception) {}
        audioCodec = null

        if (muxerStarted) {
            try {
                muxer?.stop()
                muxer?.release()
            } catch (e: Exception) {
                // Ignore errors
            }
        }
        muxerStarted = false
    }
}
