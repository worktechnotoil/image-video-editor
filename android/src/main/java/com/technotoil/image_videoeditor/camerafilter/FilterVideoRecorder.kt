package com.technotoil.image_videoeditor.camerafilter

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.view.Surface
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class FilterVideoRecorder(
    private val outputFile: String,
    private val width: Int,
    private val height: Int,
    private val drawCallback: (Canvas) -> Unit
) {

    private var videoCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    
    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var muxerStarted = false
    private var isRecording = false
    
    private var audioRecord: AudioRecord? = null
    private val bufferInfo = MediaCodec.BufferInfo()
    private val audioBufferInfo = MediaCodec.BufferInfo()

    fun start() {
        isRecording = true
        muxer = MediaMuxer(outputFile, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        setupVideoCodec()
        setupAudioCodec()
        startAudioCapture()
        
        thread { drainVideoCodec() }
        thread { drainAudioCodec() }
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
        val sampleRate = 44100
        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 128000)
        }
        audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audioCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioCodec?.start()
    }

    private fun startAudioCapture() {
        val minBufferSize = AudioRecord.getMinBufferSize(44100, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        audioRecord = AudioRecord(MediaRecorder.AudioSource.MIC, 44100, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBufferSize * 2)
        audioRecord?.startRecording()
        
        thread {
            val buffer = ByteArray(minBufferSize)
            while (isRecording) {
                val readBytes = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (readBytes > 0) {
                    val inputBufferIndex = audioCodec?.dequeueInputBuffer(10000) ?: -1
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = audioCodec?.getInputBuffer(inputBufferIndex)
                        inputBuffer?.clear()
                        inputBuffer?.put(buffer, 0, readBytes)
                        audioCodec?.queueInputBuffer(inputBufferIndex, 0, readBytes, System.nanoTime() / 1000, 0)
                    }
                }
            }
        }
    }

    private val renderExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val isRendering = java.util.concurrent.atomic.AtomicBoolean(false)

    fun onFrame() {
        if (!isRecording || !isRendering.compareAndSet(false, true)) return
        renderExecutor.execute {
            try {
                if (!isRecording) return@execute
                val canvas = inputSurface?.lockCanvas(null) ?: return@execute
                try {
                    drawCallback(canvas)
                } finally {
                    inputSurface?.unlockCanvasAndPost(canvas)
                }
            } finally {
                isRendering.set(false)
            }
        }
    }

    private fun drainVideoCodec() {
        while (isRecording || videoCodec != null) {
            val index = videoCodec?.dequeueOutputBuffer(bufferInfo, 10000) ?: -1
            if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (muxerStarted) throw RuntimeException("format changed twice")
                videoTrackIndex = muxer?.addTrack(videoCodec!!.outputFormat) ?: -1
                checkMuxerStart()
            } else if (index >= 0) {
                val encodedData = videoCodec?.getOutputBuffer(index)
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) bufferInfo.size = 0
                if (bufferInfo.size != 0 && muxerStarted) {
                    encodedData?.position(bufferInfo.offset)
                    encodedData?.limit(bufferInfo.offset + bufferInfo.size)
                    muxer?.writeSampleData(videoTrackIndex, encodedData!!, bufferInfo)
                }
                videoCodec?.releaseOutputBuffer(index, false)
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
            }
        }
    }

    private fun drainAudioCodec() {
        while (isRecording || audioCodec != null) {
            val index = audioCodec?.dequeueOutputBuffer(audioBufferInfo, 10000) ?: -1
            if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                audioTrackIndex = muxer?.addTrack(audioCodec!!.outputFormat) ?: -1
                checkMuxerStart()
            } else if (index >= 0) {
                val encodedData = audioCodec?.getOutputBuffer(index)
                if (audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) audioBufferInfo.size = 0
                if (audioBufferInfo.size != 0 && muxerStarted) {
                    encodedData?.position(audioBufferInfo.offset)
                    encodedData?.limit(audioBufferInfo.offset + audioBufferInfo.size)
                    muxer?.writeSampleData(audioTrackIndex, encodedData!!, audioBufferInfo)
                }
                audioCodec?.releaseOutputBuffer(index, false)
                if (audioBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
            }
        }
    }

    @Synchronized
    private fun checkMuxerStart() {
        if (!muxerStarted && videoTrackIndex >= 0 && audioTrackIndex >= 0) {
            muxer?.start()
            muxerStarted = true
        }
    }

    fun stop() {
        isRecording = false
        renderExecutor.shutdown()
        audioRecord?.stop()
        audioRecord?.release()
        
        try {
            videoCodec?.signalEndOfInputStream()
            Thread.sleep(500)
        } catch(e:Exception){}

        videoCodec?.stop()
        videoCodec?.release()
        videoCodec = null

        audioCodec?.stop()
        audioCodec?.release()
        audioCodec = null

        if (muxerStarted) {
            muxer?.stop()
            muxer?.release()
        }
        muxerStarted = false
    }
}
