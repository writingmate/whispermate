package com.whispermate.aidictation.util

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.sqrt

/**
 * Frequency analyzer using FFT to extract frequency bands from audio.
 * Matches iOS FrequencyAnalyzer.swift behavior.
 */
class FrequencyAnalyzer(
    private val sampleRate: Int = 16000,
    private val bandCount: Int = 6  // 6 bands for round button
) {
    private val fftSize = 512  // Smaller FFT for faster processing

    // Hann window for smoothing
    private val window = FloatArray(fftSize) { i ->
        (0.5 * (1 - cos(2 * PI * i / (fftSize - 1)))).toFloat()
    }

    // Sample accumulation buffer
    private val sampleBuffer = FloatArray(fftSize)
    private var sampleCount = 0

    // Previous bands for smoothing
    private var previousBands = FloatArray(bandCount) { 0f }

    // Voice frequency range (focused on speech)
    private val voiceStartHz = 80f
    private val voiceEndHz = 2000f

    // Signal processing parameters - much higher gain needed for small FFT magnitudes
    private val fixedGain = 300f   // High gain to amplify small FFT values to visible range

    /**
     * Analyze audio samples and return frequency bands.
     * @param samples Audio samples (normalized -1 to 1)
     * @return Array of band magnitudes (0 to 1)
     */
    private var logCounter = 0

    fun analyze(samples: FloatArray): FloatArray {
        // Accumulate samples into buffer
        for (sample in samples) {
            sampleBuffer[sampleCount] = sample
            sampleCount++
            if (sampleCount >= fftSize) {
                sampleCount = 0  // Wrap around
            }
        }

        // Use the accumulated buffer as a circular buffer
        val audioData = FloatArray(fftSize) { i ->
            val idx = (sampleCount + i) % fftSize
            sampleBuffer[idx]
        }

        // Check audio level
        val maxSample = audioData.maxOfOrNull { kotlin.math.abs(it) } ?: 0f
        logCounter++
        if (logCounter % 20 == 0) {
            android.util.Log.d("FrequencyAnalyzer", "Input max sample: $maxSample")
        }

        // Apply Hann window
        val windowed = FloatArray(fftSize) { i ->
            audioData[i] * window[i]
        }

        // Perform FFT (simple DFT for now - could optimize with FFT library)
        val magnitudes = computeMagnitudes(windowed)

        // Group into frequency bands
        val bands = groupIntoBands(magnitudes)

        // Apply signal processing
        val processed = processSignal(bands)

        return processed
    }

    /**
     * Simple DFT magnitude calculation.
     * Returns magnitude spectrum (first half only - Nyquist).
     */
    private fun computeMagnitudes(samples: FloatArray): FloatArray {
        val n = samples.size
        val halfN = n / 2
        val magnitudes = FloatArray(halfN)

        for (k in 0 until halfN) {
            var real = 0f
            var imag = 0f

            for (t in 0 until n) {
                val angle = 2 * PI * k * t / n
                real += samples[t] * cos(angle).toFloat()
                imag -= samples[t] * kotlin.math.sin(angle).toFloat()
            }

            magnitudes[k] = sqrt(real * real + imag * imag) / n
        }

        return magnitudes
    }

    /**
     * Group FFT magnitudes into frequency bands focused on voice range.
     * Uses logarithmic distribution to spread energy more evenly across bands.
     */
    private fun groupIntoBands(magnitudes: FloatArray): FloatArray {
        val bands = FloatArray(bandCount)
        val nyquist = sampleRate / 2f
        val binWidth = nyquist / magnitudes.size

        // Use logarithmic frequency bands for more even voice distribution (6 bands)
        // Voice fundamentals: 80-300Hz, harmonics: 300-3000Hz
        val freqBands = floatArrayOf(
            80f, 180f, 350f, 600f, 1000f, 1600f, 2500f
        )

        for (i in 0 until bandCount) {
            val lowFreq = freqBands[i]
            val highFreq = freqBands[i + 1]

            val startBin = (lowFreq / binWidth).toInt().coerceIn(0, magnitudes.size - 1)
            val endBin = (highFreq / binWidth).toInt().coerceIn(startBin + 1, magnitudes.size)

            if (endBin > startBin) {
                var sum = 0f
                var maxVal = 0f
                for (j in startBin until endBin.coerceAtMost(magnitudes.size)) {
                    sum += magnitudes[j]
                    if (magnitudes[j] > maxVal) maxVal = magnitudes[j]
                }
                // Use combination of sum and max for better response
                bands[i] = (sum + maxVal * 2) / 3
            }
        }

        return bands
    }

    /**
     * Apply signal processing: noise gate, gain, and smoothing.
     */
    private fun processSignal(bands: FloatArray): FloatArray {
        val processed = FloatArray(bandCount)

        val rawMax = bands.maxOrNull() ?: 0f
        if (rawMax > 0.001f) {
            android.util.Log.d("FrequencyAnalyzer", "Raw bands max=$rawMax, values=${bands.contentToString()}")
        }

        for (i in 0 until bandCount) {
            // Skip noise gate for now - just apply gain
            var value = bands[i] * fixedGain

            // Clamp to 0-1
            value = value.coerceIn(0f, 1f)

            // Asymmetric smoothing: fast attack, slow decay (like iOS)
            value = if (value > previousBands[i]) {
                previousBands[i] * 0.2f + value * 0.8f  // Quick rise
            } else {
                previousBands[i] * 0.7f + value * 0.3f  // Slow fall
            }

            processed[i] = value
            previousBands[i] = value
        }

        return processed
    }

    /**
     * Reset the analyzer state.
     */
    fun reset() {
        previousBands = FloatArray(bandCount) { 0f }
        sampleCount = 0
        for (i in sampleBuffer.indices) {
            sampleBuffer[i] = 0f
        }
    }
}
