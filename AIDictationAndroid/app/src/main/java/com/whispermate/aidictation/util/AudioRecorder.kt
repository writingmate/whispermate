package com.whispermate.aidictation.util

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File

class AudioRecorder(
    private val context: Context,
    private val enableVAD: Boolean = true
) {
    private var mediaRecorder: MediaRecorder? = null
    private var audioLevelJob: Job? = null
    private var outputFile: File? = null
    private var startTime: Long = 0
    private var frequencyAnalyzer: FrequencyAnalyzer? = null

    // Speech detection based on amplitude
    private var speechDetected = false
    private var silenceStartTime: Long = 0
    private val speechThreshold = 1000 // Amplitude threshold for speech
    private val silenceDurationMs = 1500L // 1.5 seconds of silence to auto-stop

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _audioLevel = MutableStateFlow(0f)
    val audioLevel: StateFlow<Float> = _audioLevel.asStateFlow()

    private val _frequencyBands = MutableStateFlow(FloatArray(6) { 0f })
    val frequencyBands: StateFlow<FloatArray> = _frequencyBands.asStateFlow()

    private val _speechProbability = MutableStateFlow(0f)
    val speechProbability: StateFlow<Float> = _speechProbability.asStateFlow()

    private val _shouldAutoStop = MutableStateFlow(false)
    val shouldAutoStop: StateFlow<Boolean> = _shouldAutoStop.asStateFlow()

    init {
        frequencyAnalyzer = FrequencyAnalyzer(sampleRate = 44100, bandCount = 6)
    }

    @SuppressLint("MissingPermission")
    fun start(): File? {
        try {
            val recordingsDir = File(context.filesDir, "recordings")
            recordingsDir.mkdirs()
            outputFile = File(recordingsDir, "recording_${System.currentTimeMillis()}.m4a")

            // Start MediaRecorder for high-quality output
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(outputFile?.absolutePath)
                prepare()
                start()
            }

            startTime = System.currentTimeMillis()
            _isRecording.value = true
            _shouldAutoStop.value = false
            speechDetected = false
            silenceStartTime = 0
            frequencyAnalyzer?.reset()

            // Start audio level monitoring and speech detection
            audioLevelJob = CoroutineScope(Dispatchers.Default).launch {
                var frameCount = 0
                while (isActive && _isRecording.value) {
                    try {
                        val maxAmplitude = mediaRecorder?.maxAmplitude ?: 0
                        frameCount++

                        // Detect speech based on amplitude
                        val isSpeech = maxAmplitude > speechThreshold
                        if (isSpeech) {
                            speechDetected = true
                            silenceStartTime = 0
                            _speechProbability.value = 1f
                        } else if (speechDetected) {
                            _speechProbability.value = 0f
                            // Track silence after speech
                            if (silenceStartTime == 0L) {
                                silenceStartTime = System.currentTimeMillis()
                            } else if (System.currentTimeMillis() - silenceStartTime > silenceDurationMs) {
                                _shouldAutoStop.value = true
                            }
                        }

                        // Log every 20 frames (~1 second)
                        if (frameCount % 20 == 0) {
                            android.util.Log.d("AudioRecorder", "Frame $frameCount: amplitude=$maxAmplitude, speechDetected=$speechDetected")
                        }

                        // Use logarithmic scale for better visual response
                        val normalizedLevel = if (maxAmplitude > 500) {
                            val logLevel = kotlin.math.log10(maxAmplitude.toFloat()) / 4.5f
                            (logLevel - 0.55f).coerceIn(0f, 1f)
                        } else {
                            0f
                        }
                        _audioLevel.value = normalizedLevel

                        // Generate fake frequency bands based on amplitude for visualization
                        val bands = FloatArray(6) { i ->
                            val base = normalizedLevel * (0.5f + 0.5f * kotlin.math.sin(i.toFloat() + frameCount * 0.1f).toFloat())
                            base.coerceIn(0f, 1f)
                        }
                        _frequencyBands.value = bands
                    } catch (_: Exception) { }
                    delay(50)
                }
            }

            return outputFile
        } catch (e: Exception) {
            e.printStackTrace()
            release()
            return null
        }
    }

    fun stop(): Pair<File?, Long>? {
        return try {
            val duration = System.currentTimeMillis() - startTime

            audioLevelJob?.cancel()
            _audioLevel.value = 0f
            _frequencyBands.value = FloatArray(6) { 0f }
            _speechProbability.value = 0f
            _shouldAutoStop.value = false
            _isRecording.value = false

            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null

            android.util.Log.d("AudioRecorder", "Recording stopped: duration=${duration}ms, speechDetected=$speechDetected")
            Pair(outputFile, duration)
        } catch (e: Exception) {
            e.printStackTrace()
            release()
            null
        }
    }

    fun release() {
        audioLevelJob?.cancel()

        _audioLevel.value = 0f
        _frequencyBands.value = FloatArray(6) { 0f }
        _speechProbability.value = 0f
        _shouldAutoStop.value = false
        _isRecording.value = false

        try {
            mediaRecorder?.release()
        } catch (_: Exception) { }
        mediaRecorder = null
    }

    /**
     * Check if speech was detected during recording.
     */
    fun hasSpeechBeenDetected(): Boolean = speechDetected
}
