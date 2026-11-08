package com.kadalist.kadalist

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Entirely in-process recognition; never calls Android's recognition service. */
class OfflineSpeech(private val activity: Activity, private val channel: MethodChannel) {
    companion object {
        const val PICK_MODEL = 4201
        const val MIC_PERMISSION = 4202
        init { System.loadLibrary("kadalist_speech") }
    }
    private external fun transcribe(path: String, samples: FloatArray, language: String): String
    private external fun validateModel(path: String): Boolean
    private external fun abortDecode()
    private external fun resetDecodeAbort()
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val model get() = File(activity.filesDir, "speech-model.bin")
    private var pendingImport: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var busy = false
    @Volatile private var closed = false
    private var language = "ml"
    private val recording = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    private var audio = FloatArray(0)
    private var captureError: String? = null
    private var recorder: AudioRecord? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasModel" -> result.success(model.isFile)
                "cancel" -> { cancel(); result.success(null) }
                "importModel" -> {
                    if (busy || recording.get() || pendingImport != null || pendingPermission != null) {
                        result.error("busy", "Finish the current speech operation first.", null)
                    } else {
                        pendingImport = result
                        try {
                            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                type = "*/*"
                                addCategory(Intent.CATEGORY_OPENABLE)
                                // Ask document providers to show local files only.
                                putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                            }, PICK_MODEL)
                        } catch (e: Exception) {
                            pendingImport = null
                            result.error("picker", "No local file picker is available.", null)
                        }
                    }
                }
                "start" -> {
                    val requested = call.argument<String>("language") ?: "ml"
                    if (requested !in listOf("ml", "en", "auto")) {
                        result.error("language", "Unsupported speech language.", null)
                    } else if (busy || recording.get() || pendingPermission != null || pendingImport != null) {
                        result.error("busy", "Finish the current speech operation first.", null)
                    } else if (!model.isFile) {
                        result.error("model", "Import a multilingual Whisper model first.", null)
                    } else {
                        language = requested
                        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            pendingPermission = result
                            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MIC_PERMISSION)
                        } else startCapture(result)
                    }
                }
                "stop" -> {
                    if (busy || audio.isEmpty() && recorder == null) {
                        result.error("state", "No recording is ready.", null)
                    } else {
                        recording.set(false)
                        busy = true
                        // Queued after capture, so samples and recorder have one owner.
                        worker.execute {
                            try {
                                if (cancelled.get()) throw IllegalStateException("Recording cancelled.")
                                captureError?.let { throw IllegalStateException(it) }
                                if (audio.size < 1600) throw IllegalStateException("Recording too short. Try speaking for longer.")
                                val text = transcribe(model.absolutePath, audio, language)
                                if (cancelled.get()) throw IllegalStateException("Recording cancelled.")
                                main.post {
                                    if (!closed) {
                                        if (cancelled.get()) result.error("cancelled", "Recording cancelled.", null)
                                        else result.success(text)
                                    }
                                }
                            } catch (e: Exception) {
                                main.post { if (!closed) result.error("recognition", e.message ?: "Offline recognition failed.", null) }
                            } finally {
                                audio = FloatArray(0)
                                main.post { recorder = null; busy = false }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCapture(result: MethodChannel.Result) {
        try {
            val buffer = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            check(buffer > 0) { "16 kHz microphone capture is unavailable." }
            val input = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, 16000,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(buffer, 4096))
            if (input.state != AudioRecord.STATE_INITIALIZED) {
                input.release()
                throw IllegalStateException("Microphone is unavailable.")
            }
            recorder = input
            input.startRecording()
            check(input.recordingState == AudioRecord.RECORDSTATE_RECORDING) { "Could not start microphone." }
            cancelled.set(false)
            resetDecodeAbort()
            recording.set(true)
            captureError = null
            audio = FloatArray(0)
            worker.execute {
                val samples = FloatArray(16000 * 20)
                val chunk = ShortArray(1600)
                var count = 0
                try {
                    while (recording.get() && count < samples.size) {
                        val read = input.read(chunk, 0, minOf(chunk.size, samples.size - count))
                        check(read > 0) { "Microphone capture failed. Check microphone privacy settings." }
                        for (i in 0 until read) samples[count++] = chunk[i] / 32768f
                    }
                    audio = if (cancelled.get()) FloatArray(0) else samples.copyOf(count)
                } catch (e: Exception) {
                    captureError = e.message
                    audio = FloatArray(0)
                } finally {
                    try { input.stop() } catch (_: Exception) { }
                    input.release()
                    // Leave recording flag set after the duration limit until stop/cancel.
                }
            }
            result.success(null)
        } catch (e: Exception) {
            recorder?.release()
            recorder = null
            result.error("microphone", e.message ?: "Microphone unavailable.", null)
        }
    }

    fun permissionResult(granted: Boolean) {
        val result = pendingPermission ?: return
        pendingPermission = null
        if (granted && !closed && !activity.isFinishing) startCapture(result)
        else result.error("permission", "Microphone permission is required. Enable it in Android settings or type your list.", null)
    }

    fun modelResult(uri: android.net.Uri?) {
        val result = pendingImport ?: return
        pendingImport = null
        if (uri == null) { result.success(false); return }
        busy = true
        worker.execute {
            val temporary = File(activity.filesDir, "speech-model.import")
            try {
                activity.contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "Cannot read this local model file." }
                    temporary.outputStream().use { output ->
                        val buffer = ByteArray(65536)
                        var total = 0L
                        while (true) {
                            val read = input.read(buffer)
                            if (read < 0) break
                            total += read
                            require(total <= 600L * 1024 * 1024) { "Choose tiny, base or small (at most 600 MiB)." }
                            output.write(buffer, 0, read)
                        }
                    }
                }
                val header = ByteArray(48)
                java.io.DataInputStream(temporary.inputStream()).use { it.readFully(header) }
                val values = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                val layers = values.getInt(20)
                val width = mapOf(4 to 384, 6 to 512, 12 to 768)[layers]
                require(values.getInt(0) == 0x67676d6c && width != null &&
                    values.getInt(4) == 51865 && values.getInt(8) == 1500 &&
                    values.getInt(12) == width && values.getInt(16) == width / 64 &&
                    values.getInt(24) == 448 && values.getInt(28) == width &&
                    values.getInt(32) == width / 64 && values.getInt(36) == layers &&
                    values.getInt(40) == 80) { "Choose a multilingual GGML tiny, base or small Whisper model (without .en)." }
                require(validateModel(temporary.absolutePath)) { "Invalid or English-only model. Choose a multilingual model without .en in its name." }
                check(temporary.renameTo(model)) { "Could not install model. Check free storage." }
                main.post { if (!closed) result.success(true) }
            } catch (e: Exception) {
                main.post { if (!closed) result.error("model", e.message ?: "Model import failed.", null) }
            } finally {
                temporary.delete()
                main.post { busy = false }
            }
        }
    }

    fun cancel() {
        pendingPermission?.error("cancelled", "Recording cancelled.", null)
        pendingPermission = null
        cancelled.set(true)
        recording.set(false)
        abortDecode()
        if (!worker.isShutdown) {
            // Do not allow a new session to reset flags until capture/decode exits.
            busy = true
            worker.execute {
                audio = FloatArray(0)
                main.post { recorder = null; busy = false }
            }
        }
    }

    fun close() {
        closed = true
        cancel()
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
