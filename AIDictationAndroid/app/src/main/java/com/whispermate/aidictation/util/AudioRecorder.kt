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
    private var audioRecord: AudioRecord? = null
    private var audioLevelJob: Job? = null
    private var vadJob: Job? = null
    private var outputFile: File? = null
    private var startTime: Long = 0
    private var sileroVAD: SileroVAD? = null
    private var frequencyAnalyzer: FrequencyAnalyzer? = null

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

    // VAD settings
    companion object {
        private const val VAD_SAMPLE_RATE = 16000
        private const val VAD_CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val VAD_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    init {
        if (enableVAD) {
            try {
                sileroVAD = SileroVAD(context)
            } catch (e: Exception) {
                android.util.Log.e("AudioRecorder", "Failed to initialize VAD", e)
            }
        }
        frequencyAnalyzer = FrequencyAnalyzer(sampleRate = VAD_SAMPLE_RATE, bandCount = 6)
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
            sileroVAD?.reset()
            frequencyAnalyzer?.reset()

            // Start audio level monitoring
            audioLevelJob = CoroutineScope(Dispatchers.Default).launch {
                while (isActive && _isRecording.value) {
                    try {
                        val maxAmplitude = mediaRecorder?.maxAmplitude ?: 0
                        // Use logarithmic scale for better visual response
                        // Balanced sensitivity - not too sensitive, not too quiet
                        val normalizedLevel = if (maxAmplitude > 100) {
                            // Log scale with threshold to filter noise
                            val logLevel = kotlin.math.log10(maxAmplitude.toFloat()) / 4.5f
                            (logLevel - 0.4f).coerceIn(0f, 1f)
                        } else {
                            0f
                        }
                        _audioLevel.value = normalizedLevel
                    } catch (_: Exception) { }
                    delay(50)
                }
            }

            // Start VAD/frequency processing
            // Always start for frequency analysis, VAD is optional
            startVADProcessing()

            return outputFile
        } catch (e: Exception) {
            e.printStackTrace()
            release()
            return null
        }
    }

    @SuppressLint("MissingPermission")
    private fun startVADProcessing() {
        android.util.Log.d("AudioRecorder", "startVADProcessing called")

        val bufferSize = AudioRecord.getMinBufferSize(
            VAD_SAMPLE_RATE,
            VAD_CHANNEL_CONFIG,
            VAD_AUDIO_FORMAT
        )
        android.util.Log.d("AudioRecorder", "Buffer size: $bufferSize")

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            VAD_SAMPLE_RATE,
            VAD_CHANNEL_CONFIG,
            VAD_AUDIO_FORMAT,
            bufferSize * 2
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            android.util.Log.e("AudioRecorder", "Failed to initialize AudioRecord for VAD, state: ${audioRecord?.state}")
            audioRecord?.release()
            audioRecord = null
            return
        }

        android.util.Log.d("AudioRecorder", "AudioRecord initialized, starting recording")
        audioRecord?.startRecording()

        android.util.Log.d("AudioRecorder", "Starting VAD job, audioRecord state: ${audioRecord?.state}")

        vadJob = CoroutineScope(Dispatchers.Default).launch {
            val buffer = ShortArray(512) // Silero VAD expects 512 samples at 16kHz
            var frameCount = 0

            while (isActive && _isRecording.value) {
                try {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        frameCount++
                        // Convert shorts to floats (-1 to 1)
                        val floatBuffer = FloatArray(read) { i ->
                            buffer[i] / 32768f
                        }

                        // Process through VAD
                        val probability = sileroVAD?.process(floatBuffer) ?: 0f
                        _speechProbability.value = probability

                        // Process frequency analysis
                        val bands = frequencyAnalyzer?.analyze(floatBuffer) ?: FloatArray(6) { 0f }
                        _frequencyBands.value = bands

                        // Log every 20 frames (~1 second)
                        if (frameCount % 20 == 0) {
                            val maxBand = bands.maxOrNull() ?: 0f
                            val avgBand = bands.average().toFloat()
                            android.util.Log.d("AudioRecorder", "Frame $frameCount: prob=$probability, bands max=$maxBand avg=$avgBand")
                        }

                        // Check if we should auto-stop
                        if (sileroVAD?.shouldStopRecording(probability) == true) {
                            _shouldAutoStop.value = true
                        }
                    } else {
                        android.util.Log.w("AudioRecorder", "AudioRecord read returned $read")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("AudioRecorder", "VAD processing error", e)
                }
            }
            android.util.Log.d("AudioRecorder", "VAD job ended after $frameCount frames")
        }
    }

    fun stop(): Pair<File?, Long>? {
        return try {
            val duration = System.currentTimeMillis() - startTime

            // Stop VAD first
            vadJob?.cancel()
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null

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

            Pair(outputFile, duration)
        } catch (e: Exception) {
            e.printStackTrace()
            release()
            null
        }
    }

    fun release() {
        vadJob?.cancel()
        audioLevelJob?.cancel()

        audioRecord?.release()
        audioRecord = null

        _audioLevel.value = 0f
        _frequencyBands.value = FloatArray(6) { 0f }
        _speechProbability.value = 0f
        _shouldAutoStop.value = false
        _isRecording.value = false

        try {
            mediaRecorder?.release()
        } catch (_: Exception) { }
        mediaRecorder = null

        sileroVAD?.release()
        sileroVAD = null
    }

    /**
     * Check if speech was detected during recording.
     */
    fun hasSpeechBeenDetected(): Boolean = sileroVAD?.hasSpeechBeenDetected() ?: true
}
