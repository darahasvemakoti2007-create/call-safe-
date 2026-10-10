package com.example.guard_call

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "guardcall/audio_capture"
    private val EVENT_CHANNEL = "guardcall/audio_stream"
    private val PERMISSION_REQUEST_CODE = 1001

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private val isRecording = AtomicBoolean(false)
    private var audioEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPermissionResult: MethodChannel.Result? = null

    // Audio format specification: 16000Hz, Mono, 16-bit PCM
    private val SAMPLE_RATE = 16000
    private val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
    private val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    val hasMic = packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)
                    result.success(hasMic)
                }
                "checkPermission" -> {
                    result.success(checkPermissionStatus())
                }
                "requestPermission" -> {
                    requestMicrophonePermission(result)
                }
                "getAudioFormat" -> {
                    val formatMap = mapOf(
                        "sampleRate" to SAMPLE_RATE,
                        "channelCount" to 1,
                        "bitDepth" to 16,
                        "encoding" to "audio/pcm;rate=16000;channels=1"
                    )
                    result.success(formatMap)
                }
                "startCapture" -> {
                    startAudioCapture(result)
                }
                "stopCapture" -> {
                    stopAudioCapture(result)
                }
                "isCapturing" -> {
                    result.success(isRecording.get())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            }
        )
    }

    private fun checkPermissionStatus(): String {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (granted) return "granted"
        return "notDetermined"
    }

    private fun requestMicrophonePermission(result: MethodChannel.Result) {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success("granted")
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                pendingPermissionResult?.success("granted")
            } else {
                val permanentlyDenied = !ActivityCompat.shouldShowRequestPermissionRationale(
                    this,
                    Manifest.permission.RECORD_AUDIO
                )
                if (permanentlyDenied) {
                    pendingPermissionResult?.success("permanentlyDenied")
                } else {
                    pendingPermissionResult?.success("denied")
                }
            }
            pendingPermissionResult = null
        }
    }

    private fun startAudioCapture(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "RECORD_AUDIO permission is not granted.", null)
            return
        }

        if (isRecording.get()) {
            result.success(true)
            return
        }

        try {
            val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
                result.error("INITIALIZATION_FAILED", "Invalid AudioRecord buffer parameters.", null)
                return
            }

            val bufferSize = Math.max(minBufferSize * 2, 4096)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord?.release()
                audioRecord = null
                result.error("INITIALIZATION_FAILED", "AudioRecord hardware initialization failed.", null)
                return
            }

            audioRecord?.startRecording()
            isRecording.set(true)

            recordingThread = Thread({
                val readBuffer = ByteArray(bufferSize)
                while (isRecording.get()) {
                    val recorder = audioRecord ?: break
                    val bytesRead = recorder.read(readBuffer, 0, readBuffer.size)
                    if (bytesRead > 0) {
                        val chunk = readBuffer.copyOf(bytesRead)
                        mainHandler.post {
                            audioEventSink?.success(chunk)
                        }
                    } else if (bytesRead < 0) {
                        mainHandler.post {
                            audioEventSink?.error(
                                "CAPTURE_ERROR",
                                "AudioRecord read returned error: $bytesRead",
                                null
                            )
                        }
                        break
                    }
                }
            }, "GuardCallNativeAudioRecorder")
            recordingThread?.start()

            result.success(true)
        } catch (e: Exception) {
            stopCaptureInternal()
            result.error("CAPTURE_EXCEPTION", "Failed to start audio capture: ${e.message}", null)
        }
    }

    private fun stopAudioCapture(result: MethodChannel.Result) {
        stopCaptureInternal()
        result.success(true)
    }

    private fun stopCaptureInternal() {
        isRecording.set(false)
        try {
            recordingThread?.interrupt()
            recordingThread?.join(300)
        } catch (_: Exception) {}
        recordingThread = null

        try {
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                audioRecord?.stop()
            }
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }

    override fun onDestroy() {
        stopCaptureInternal()
        super.onDestroy()
    }
}
