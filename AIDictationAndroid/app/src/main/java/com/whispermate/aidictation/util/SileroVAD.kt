package com.whispermate.aidictation.util

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.nio.FloatBuffer
import java.nio.LongBuffer

/**
 * Silero Voice Activity Detection using ONNX Runtime.
 * Detects speech in audio samples and provides silence detection for auto-stop.
 */
class SileroVAD(context: Context) {

    private val ortEnvironment: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val ortSession: OrtSession

    // Model state (required for stateful inference)
    private var state: Array<FloatArray>
    private var stateShape = longArrayOf(2, 1, 128)

    // Sample rate - Silero VAD expects 16kHz
    private val sampleRate = 16000

    // Silence detection state
    private var silenceStartTime: Long = 0
    private var speechDetected = false

    companion object {
        private const val MODEL_FILE = "silero_vad.onnx"
        private const val SPEECH_THRESHOLD = 0.5f
        private const val SILENCE_DURATION_MS = 1500L // 1.5 seconds of silence to stop
        private const val MIN_SPEECH_DURATION_MS = 300L // Minimum speech before considering silence
    }

    init {
        // Load model from assets
        val modelBytes = context.assets.open(MODEL_FILE).use { it.readBytes() }
        ortSession = ortEnvironment.createSession(modelBytes)

        // Initialize state tensors
        state = Array(2) { FloatArray(128) { 0f } }
    }

    /**
     * Process audio samples and return speech probability.
     * @param audioSamples Float array of audio samples (16kHz, mono, normalized -1 to 1)
     * @return Speech probability (0.0 to 1.0)
     */
    suspend fun process(audioSamples: FloatArray): Float = withContext(Dispatchers.Default) {
        try {
            // Silero VAD expects chunks of specific sizes (512, 1024, 1536 samples for 16kHz)
            // We'll use 512 samples per chunk
            val chunkSize = 512
            if (audioSamples.size < chunkSize) {
                return@withContext 0f
            }

            // Process the last chunk
            val chunk = if (audioSamples.size >= chunkSize) {
                audioSamples.sliceArray((audioSamples.size - chunkSize) until audioSamples.size)
            } else {
                audioSamples
            }

            // Create input tensor - wrap as 2D array for ONNX
            val inputShape = longArrayOf(1, chunk.size.toLong())
            val inputBuffer = FloatBuffer.wrap(chunk)
            val inputTensor = OnnxTensor.createTensor(ortEnvironment, inputBuffer, inputShape)

            // Create state tensor - flatten the 2D state array
            val flatState = state.flatMap { it.toList() }.toFloatArray()
            val stateBuffer = FloatBuffer.wrap(flatState)
            val stateTensor = OnnxTensor.createTensor(ortEnvironment, stateBuffer, stateShape)

            // Create sample rate tensor
            val srBuffer = LongBuffer.wrap(longArrayOf(sampleRate.toLong()))
            val srTensor = OnnxTensor.createTensor(ortEnvironment, srBuffer, longArrayOf(1))

            // Run inference
            val inputs = mapOf(
                "input" to inputTensor,
                "state" to stateTensor,
                "sr" to srTensor
            )

            val results = ortSession.run(inputs)

            // Get output probability
            val outputTensor = results[0] as OnnxTensor
            val probability = (outputTensor.floatBuffer.get())

            // Update state for next iteration
            val newStateTensor = results[1] as OnnxTensor
            val newStateBuffer = newStateTensor.floatBuffer
            for (i in 0 until 2) {
                for (j in 0 until 128) {
                    state[i][j] = newStateBuffer.get()
                }
            }

            // Clean up tensors
            inputTensor.close()
            stateTensor.close()
            srTensor.close()
            results.close()

            probability
        } catch (e: Exception) {
            android.util.Log.e("SileroVAD", "Error processing audio", e)
            0f
        }
    }

    /**
     * Check if speech has been detected followed by silence.
     * @param speechProbability Current speech probability from process()
     * @return true if we should stop recording (speech was detected, then silence for threshold duration)
     */
    fun shouldStopRecording(speechProbability: Float): Boolean {
        val currentTime = System.currentTimeMillis()
        val isSpeech = speechProbability > SPEECH_THRESHOLD

        if (isSpeech) {
            speechDetected = true
            silenceStartTime = 0
        } else if (speechDetected) {
            // We've had speech, now tracking silence
            if (silenceStartTime == 0L) {
                silenceStartTime = currentTime
            } else if (currentTime - silenceStartTime > SILENCE_DURATION_MS) {
                return true
            }
        }

        return false
    }

    /**
     * Check if any speech has been detected so far.
     */
    fun hasSpeechBeenDetected(): Boolean = speechDetected

    /**
     * Reset the VAD state for a new recording session.
     */
    fun reset() {
        state = Array(2) { FloatArray(128) { 0f } }
        silenceStartTime = 0
        speechDetected = false
    }

    /**
     * Release resources.
     */
    fun release() {
        try {
            ortSession.close()
        } catch (e: Exception) {
            android.util.Log.e("SileroVAD", "Error releasing session", e)
        }
    }
}
